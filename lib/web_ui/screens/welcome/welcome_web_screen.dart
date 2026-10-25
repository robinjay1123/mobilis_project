import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dialogs/download_apk_dialog.dart';
import 'models/curated_vehicle_data.dart';
import 'sections/faq_section.dart';
import 'sections/footer_section.dart';
import 'sections/hero_section.dart';
import 'sections/pangasinan_hub_section.dart';
import 'sections/quick_pangasinan_picker.dart';
import 'sections/rate_estimator_section.dart';
import 'sections/safety_features_section.dart';
import 'sections/sticky_header.dart';
import 'sections/three_in_one_platform_section.dart';
import 'sections/top_announcement_bar.dart';
import 'sections/vehicle_showroom_section.dart';
import 'widgets/grid_mesh_painter.dart';

/// Clean Architecture Welcome Landing Web Screen
/// Orchestrates modular sections and live fleet availability.
class WelcomeWebScreen extends StatefulWidget {
  const WelcomeWebScreen({super.key});

  @override
  State<WelcomeWebScreen> createState() => _WelcomeWebScreenState();
}

class _WelcomeWebScreenState extends State<WelcomeWebScreen> {
  final ScrollController _scrollController = ScrollController();

  // Navigation Keys for Smooth Section Scrolling
  final GlobalKey _vehiclesKey = GlobalKey();
  final GlobalKey _modesKey = GlobalKey();
  final GlobalKey _estimatorKey = GlobalKey();
  final GlobalKey _hubKey = GlobalKey();
  final GlobalKey _faqKey = GlobalKey();
  final GlobalKey _contactKey = GlobalKey();

  // Vehicle Catalog State
  String _selectedCategory = 'all';
  List<Map<String, dynamic>> _liveVehicles = [];
  bool _isLoadingVehicles = true;

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

      try {
        final companyRes = await supabase
            .from('vehicles')
            .select(
              'id, brand, model, year, plate_number, price_per_day, seats, '
              'transmission, fuel_type, vehicle_type, vehicle_name, '
              'description, status, rating, rating_count, '
              'vehicle_images(image_url, display_order)',
            )
            .neq('status', 'deleted')
            .order('created_at', ascending: false)
            .limit(24);

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

  Map<String, dynamic> _normalizeVehicle(
    Map<String, dynamic> raw, {
    required bool isPartner,
  }) {
    String brand = _capitalize(raw['brand']?.toString() ?? 'Toyota');
    String model = _capitalize(raw['model']?.toString() ?? 'Model');
    if (brand.toUpperCase() == 'BYD') brand = 'BYD';
    if (brand.toUpperCase() == 'BMW') brand = 'BMW';

    final year = raw['year']?.toString() ?? '2024';
    final seats = (raw['seats'] as num?)?.toInt() ?? 5;
    final transmission = _cleanText(raw['transmission']) ?? 'Manual';
    final fuelType = _cleanText(raw['fuel_type']) ?? 'Gasoline';
    final priceDay = (raw['price_per_day'] as num?)?.toDouble() ?? 1800.0;
    final priceHour =
        (raw['price_per_hour'] as num?)?.toDouble() ??
        (priceDay / 10).roundToDouble();
    final plate = raw['plate_number']?.toString().trim() ?? '';
    final category =
        raw['category']?.toString() ?? (isPartner ? 'Partner Vehicle' : 'Sedan');
    final vehicleType = raw['vehicle_type']?.toString() ?? category;

    String? imageUrl;
    final images = raw['vehicle_images'];
    if (images is List && images.isNotEmpty) {
      final imgList = List<Map<String, dynamic>>.from(
        images.whereType<Map<String, dynamic>>(),
      );
      imgList.sort(
        (a, b) => ((a['display_order'] as num?) ?? 0).compareTo(
          (b['display_order'] as num?) ?? 0,
        ),
      );
      for (final img in imgList) {
        final url = img['image_url']?.toString();
        if (url != null && url.isNotEmpty) {
          imageUrl = url;
          break;
        }
      }
    }
    imageUrl ??= raw['image_url']?.toString();

    final tag =
        isPartner
            ? (raw['owner_name'] != null &&
                    raw['owner_name'].toString().trim().isNotEmpty
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

  List<Map<String, dynamic>> get _displayVehicles {
    final source =
        _liveVehicles.isNotEmpty
            ? _liveVehicles
            : CuratedVehicleData.fallbackVehicles;

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

  void _goToLogin() {
    Navigator.of(context).pushNamed('/login');
  }

  void _goToSignup() {
    showDownloadApkDialog(context);
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
          const Positioned.fill(
            child: CustomPaint(
              painter: GridMeshPainter(),
            ),
          ),

          // Main Scrollable Body
          SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                TopAnnouncementBar(isDesktop: isDesktop, width: width),
                StickyHeader(
                  isDesktop: isDesktop,
                  width: width,
                  onScrollToVehicles: () => _scrollToSection(_vehiclesKey),
                  onScrollToModes: () => _scrollToSection(_modesKey),
                  onScrollToHub: () => _scrollToSection(_hubKey),
                  onScrollToEstimator: () => _scrollToSection(_estimatorKey),
                  onScrollToFaq: () => _scrollToSection(_faqKey),
                  onScrollToContact: () => _scrollToSection(_contactKey),
                  onShowDownloadApk: () => showDownloadApkDialog(context),
                  onLogin: _goToLogin,
                  onSignup: _goToSignup,
                ),
                HeroSection(
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                  width: width,
                  onBrowseVehicles: () => _scrollToSection(_vehiclesKey),
                  onDownloadApk: () => showDownloadApkDialog(context),
                  onUrdanetaHub: () => _scrollToSection(_hubKey),
                ),
                QuickPangasinanPicker(
                  isDesktop: isDesktop,
                  width: width,
                  onCheckAvailability: () => showDownloadApkDialog(context),
                ),
                VehicleShowroomSection(
                  sectionKey: _vehiclesKey,
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                  width: width,
                  vehicles: _displayVehicles,
                  isLoading: _isLoadingVehicles,
                  selectedCategory: _selectedCategory,
                  onSelectCategory: (cat) => setState(() => _selectedCategory = cat),
                  onBookVehicle: (v) => showDownloadApkDialog(context, selectedVehicle: v),
                ),
                ThreeInOnePlatformSection(
                  sectionKey: _modesKey,
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                  width: width,
                  onSignup: _goToSignup,
                ),
                PangasinanHubSection(
                  sectionKey: _hubKey,
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                  width: width,
                ),
                RateEstimatorSection(
                  sectionKey: _estimatorKey,
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                  width: width,
                  onProceedToBook: () => showDownloadApkDialog(context),
                ),
                SafetyFeaturesSection(
                  isDesktop: isDesktop,
                  isTablet: isTablet,
                  width: width,
                ),
                FaqSection(
                  sectionKey: _faqKey,
                  isDesktop: isDesktop,
                  width: width,
                ),
                FooterSection(
                  contactKey: _contactKey,
                  isDesktop: isDesktop,
                  width: width,
                  onSignup: _goToSignup,
                  onDownloadApk: () => showDownloadApkDialog(context),
                  onLogin: _goToLogin,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
