import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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
  double _estimatorDeliveryKm = 10.0;

  // Real Database Vehicles + Rich Fallbacks
  List<Map<String, dynamic>> _liveVehicles = [];
  bool _isLoadingVehicles = true;

  // Contacts & Brand Data
  static const String hotline1 = '0962-269-9862';
  static const String hotline2 = '0955-281-1306';
  static const String facebookUrl = 'https://www.facebook.com/psdc.dagupan';
  static const String mainOfficeLocation = 'Urdaneta City, Pangasinan, Philippines';

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
      final response = await supabase
          .from('vehicles')
          .select('id, brand, model, year, price_per_day, price_per_hour, seats, transmission, fuel_type, category, vehicle_type, vehicle_images(image_url)')
          .eq('status', 'approved')
          .limit(8);

      if (response.isNotEmpty && mounted) {
        setState(() {
          _liveVehicles = List<Map<String, dynamic>>.from(response);
          _isLoadingVehicles = false;
        });
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isLoadingVehicles = false;
      });
    }
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
    Navigator.of(context).pushNamed('/signup');
  }

  // Curated fallback vehicle list
  List<Map<String, dynamic>> get _curatedVehicles => [
    {
      'brand': 'Toyota',
      'model': 'Vios 1.3 XLE Dual VVT-i',
      'year': 2024,
      'category': 'Sedan',
      'seats': 5,
      'transmission': 'Automatic',
      'fuel_type': 'Gasoline',
      'price_per_day': 1800.0,
      'price_per_hour': 180.0,
      'image_url': 'https://images.unsplash.com/photo-1590362891991-f776e747a588?auto=format&fit=crop&w=800&q=80',
      'tag': 'Best Seller',
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
      'tag': 'Premium 7-Seater',
    },
    {
      'brand': 'Toyota',
      'model': 'Innova 2.8 E Diesel AT',
      'year': 2023,
      'category': 'MPV',
      'seats': 8,
      'transmission': 'Automatic',
      'fuel_type': 'Diesel',
      'price_per_day': 2800.0,
      'price_per_hour': 300.0,
      'image_url': 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?auto=format&fit=crop&w=800&q=80',
      'tag': 'Family Favorite',
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
      'tag': 'Group & Tour Van',
    },
    {
      'brand': 'Mitsubishi',
      'model': 'Xpander Cross 1.5 AT',
      'year': 2024,
      'category': 'MPV',
      'seats': 7,
      'transmission': 'Automatic',
      'fuel_type': 'Gasoline',
      'price_per_day': 2600.0,
      'price_per_hour': 280.0,
      'image_url': 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=800&q=80',
      'tag': 'Comfort Cruiser',
    },
    {
      'brand': 'Toyota',
      'model': 'Wigo 1.0G VVT-i',
      'year': 2024,
      'category': 'Compact',
      'seats': 5,
      'transmission': 'Automatic',
      'fuel_type': 'Gasoline',
      'price_per_day': 1500.0,
      'price_per_hour': 160.0,
      'image_url': 'https://images.unsplash.com/photo-1541899481282-d53bffe3c35d?auto=format&fit=crop&w=800&q=80',
      'tag': 'Fuel Efficient',
    },
  ];

  List<Map<String, dynamic>> get _displayVehicles {
    final source = _liveVehicles.isNotEmpty ? _liveVehicles : _curatedVehicles;
    if (_selectedCategory == 'all') return source;
    return source.where((v) {
      final cat = (v['category'] ?? v['vehicle_type'] ?? '').toString().toLowerCase();
      return cat.contains(_selectedCategory.toLowerCase());
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
            child: Column(
              children: [
                _buildTopAnnouncementBar(isDesktop),
                _buildStickyHeader(isDesktop),
                _buildHeroSection(isDesktop, isTablet),
                _buildQuickPangasinanPicker(isDesktop),
                _buildVehicleShowroomSection(isDesktop, isTablet),
                _buildThreeInOnePlatformSection(isDesktop, isTablet),
                _buildPangasinanHubSection(isDesktop, isTablet),
                _buildRateEstimatorSection(isDesktop, isTablet),
                _buildWhyMobilisSafetySection(isDesktop, isTablet),
                _buildFaqSection(isDesktop),
                _buildPreFooterCta(isDesktop),
                _buildFooterSection(isDesktop),
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
  Widget _buildTopAnnouncementBar(bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.location_on_rounded, size: 13, color: AppColors.primary),
                        SizedBox(width: 5),
                        Text(
                          'PANGASINAN & NEARBY PROVINCES ONLY',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isDesktop) ...[
                    const SizedBox(width: 16),
                    const Text(
                      '•   Main Office: Urdaneta City   •   PSDC Fleet & Verified Partners',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  InkWell(
                    onTap: () => _callPhone(hotline1),
                    child: const Row(
                      children: [
                        Icon(Icons.phone_in_talk_rounded, size: 13, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text(
                          hotline1,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isDesktop) ...[
                    const SizedBox(width: 16),
                    InkWell(
                      onTap: () => _openUrl(facebookUrl),
                      child: const Row(
                        children: [
                          FaIcon(FontAwesomeIcons.facebook, size: 13, color: Color(0xFF1877F2)),
                          SizedBox(width: 6),
                          Text(
                            'fb.com/psdc.dagupan',
                            style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
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
  Widget _buildStickyHeader(bool isDesktop) {
    return Container(
      width: double.infinity,
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 24),
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
                onTap: () => _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFD740), Color(0xFFFFB300)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Image.asset('assets/icon/logo-black.png', fit: BoxFit.contain),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'MOBILIS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'PSDC',
                                style: TextStyle(
                                  color: Color(0xFF030A18),
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
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

              // Login / Sign Up Actions
              Row(
                children: [
                  OutlinedButton(
                    onPressed: _goToLogin,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0x33FFFFFF)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Log In', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _goToSignup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: const Color(0xFF030A18),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      elevation: 4,
                      shadowColor: AppColors.primary.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Row(
                      children: [
                        Text('Book / Register', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
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
  Widget _buildHeroSection(bool isDesktop, bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: isDesktop ? 70 : 40,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            children: [
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, size: 16, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'PANGASINAN’S PREMIER 100% CAR RENTAL SERVICE',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Big Catchy Title
              Text(
                'Rent a Car & Enjoy the Journey\nExclusively in Pangasinan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isDesktop ? 54 : (isTablet ? 40 : 32),
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 18),

              // Description
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: Text(
                  'Explore Pangasinan with ease. Flexible Hourly (12 hrs minimum) & Daily rentals for Sedans, SUVs, MPVs, and 15-Seat Tour Vans. Choose self-drive or hire a professional driver with 24/7 active GPS tracking.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF94A3B8),
                    fontSize: isDesktop ? 16 : 14.5,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons
              Wrap(
                spacing: 16,
                runSpacing: 14,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _scrollToSection(_vehiclesKey),
                    icon: const Icon(Icons.directions_car_rounded, size: 18),
                    label: const Text('Browse Available Vehicles', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: const Color(0xFF030A18),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 8,
                      shadowColor: AppColors.primary.withValues(alpha: 0.45),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _scrollToSection(_hubKey),
                    icon: const Icon(Icons.location_city_rounded, size: 18, color: AppColors.primary),
                    label: const Text('Our Urdaneta Hub & Contacts', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0x33FFFFFF)),
                      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),

              // Key Trust Metric Cards
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A1733),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x22FFFFFF)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildHeroStat('Urdaneta HQ', 'Central Pangasinan Office'),
                      _buildHeroStatDivider(),
                      _buildHeroStat('100% GPS', 'Active Satellite Tracking'),
                      _buildHeroStatDivider(),
                      _buildHeroStat('Self-Drive / Driver', 'Flexible Rental Options'),
                      if (isDesktop) ...[
                        _buildHeroStatDivider(),
                        _buildHeroStat('12h to Multi-Day', 'Half-day & Daily Rates'),
                      ],
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
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
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
  Widget _buildQuickPangasinanPicker(bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Container(
            padding: const EdgeInsets.all(20),
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
              runSpacing: 16,
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
                ElevatedButton.icon(
                  onPressed: _goToLogin,
                  icon: const Icon(Icons.search_rounded, size: 18),
                  label: const Text('Check Availability', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: const Color(0xFF030A18),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
  Widget _buildVehicleShowroomSection(bool isDesktop, bool isTablet) {
    final vehicles = _displayVehicles;

    return Container(
      key: _vehiclesKey,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: isDesktop ? 80 : 50,
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
                  fontSize: isDesktop ? 36 : 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'All vehicles undergo 100% digital safety inspections and include real-time satellite GPS tracking.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              ),
              const SizedBox(height: 32),

              // Category Filter Tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildCategoryFilterTab('all', 'All Vehicles'),
                    _buildCategoryFilterTab('sedan', 'Sedans (5-Seats)'),
                    _buildCategoryFilterTab('suv', 'SUVs (7-Seats)'),
                    _buildCategoryFilterTab('mpv', 'MPVs (7-8 Seats)'),
                    _buildCategoryFilterTab('van', 'Tour Vans (15-Seats)'),
                    _buildCategoryFilterTab('compact', 'Compact Hatchbacks'),
                  ],
                ),
              ),
              const SizedBox(height: 40),

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
                    if (constraints.maxWidth < 700) {
                      crossAxisCount = 1;
                    } else if (constraints.maxWidth < 1050) {
                      crossAxisCount = 2;
                    }

                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: vehicles.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 24,
                        childAspectRatio: 0.82,
                      ),
                      itemBuilder: (context, index) {
                        return _buildVehicleCard(vehicles[index]);
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

  Widget _buildCategoryFilterTab(String key, String label) {
    final isSelected = _selectedCategory == key;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        onTap: () => setState(() => _selectedCategory = key),
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : const Color(0xFF0A1733),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isSelected ? AppColors.primary : const Color(0x22FFFFFF),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? const Color(0xFF030A18) : const Color(0xFFCBD5E1),
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleCard(Map<String, dynamic> vehicle) {
    final brand = vehicle['brand']?.toString() ?? 'Toyota';
    final model = vehicle['model']?.toString() ?? 'Model';
    final year = vehicle['year']?.toString() ?? '2024';
    final seats = vehicle['seats']?.toString() ?? '5';
    final transmission = vehicle['transmission']?.toString() ?? 'Automatic';
    final fuel = vehicle['fuel_type']?.toString() ?? 'Gasoline';
    final priceDay = (vehicle['price_per_day'] as num?)?.toDouble() ?? 1800.0;
    final priceHour = (vehicle['price_per_hour'] as num?)?.toDouble() ?? (priceDay / 10);
    final tag = vehicle['tag']?.toString() ?? 'Available in Pangasinan';
    
    String? imageUrl = vehicle['image_url']?.toString();
    if (imageUrl == null && vehicle['vehicle_images'] is List && (vehicle['vehicle_images'] as List).isNotEmpty) {
      imageUrl = vehicle['vehicle_images'][0]['image_url']?.toString();
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A1838),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x22FFFFFF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vehicle Image Container
          Stack(
            children: [
              Container(
                height: 180,
                width: double.infinity,
                color: const Color(0xFF061026),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildFallbackCarGraphic(),
                      )
                    : _buildFallbackCarGraphic(),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      color: Color(0xFF030A18),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const Positioned(
                top: 12,
                right: 12,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: Color(0x99000000),
                  child: Icon(Icons.gps_fixed_rounded, size: 14, color: AppColors.primary),
                ),
              ),
            ],
          ),

          // Details Section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$brand $model',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$year Model  •  GPS Monitored',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Specs Chips
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _buildSpecBadge(Icons.people_alt_outlined, '$seats Seats'),
                          _buildSpecBadge(Icons.settings_outlined, transmission),
                          _buildSpecBadge(Icons.local_gas_station_outlined, fuel),
                        ],
                      ),
                    ],
                  ),

                  // Pricing & Action
                  Column(
                    children: [
                      const Divider(color: Color(0x1AFFFFFF), height: 16),
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                '₱${priceHour.toStringAsFixed(0)}/hr (12h min)',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: _goToLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: const Color(0xFF030A18),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Book Now', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackCarGraphic() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_car_rounded, size: 54, color: AppColors.primary.withValues(alpha: 0.6)),
          const SizedBox(height: 6),
          const Text('Mobilis Verified Car', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildSpecBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF06132D),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF94A3B8)),
          const SizedBox(width: 4),
          Text(
            text,
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

  // ==========================================
  // 6. 3-IN-1 PLATFORM SECTION (RENTER, DRIVER, PARTNER)
  // ==========================================
  Widget _buildThreeInOnePlatformSection(bool isDesktop, bool isTablet) {
    return Container(
      key: _modesKey,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: isDesktop ? 80 : 50,
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
                  fontSize: isDesktop ? 36 : 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Whether you want to rent a car, drive professionally, or earn passive income with your vehicle—Mobilis PSDC connects everything seamlessly.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              ),
              const SizedBox(height: 40),

              // Role Tabs Switcher
              Container(
                padding: const EdgeInsets.all(6),
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
              const SizedBox(height: 36),

              // Active Role Tab Details Card
              _buildActiveRoleContent(isDesktop),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF030A18) : const Color(0xFF94A3B8),
            fontSize: 13.5,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildActiveRoleContent(bool isDesktop) {
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
  }) {
    return Container(
      padding: const EdgeInsets.all(36),
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
      child: Row(
        children: [
          Expanded(
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
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
                const SizedBox(height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: features.map((f) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 16),
                      const SizedBox(width: 8),
                      Text(f, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  )).toList(),
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 7. PANGASINAN HUB & COVERAGE SECTION
  // ==========================================
  Widget _buildPangasinanHubSection(bool isDesktop, bool isTablet) {
    return Container(
      key: _hubKey,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: isDesktop ? 80 : 50,
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
                  fontSize: isDesktop ? 36 : 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Headquartered in Urdaneta City with coverage spanning all major towns and cities across Pangasinan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              ),
              const SizedBox(height: 40),

              // Hub Info Cards
              Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: [
                  _buildHubDetailCard(
                    icon: Icons.apartment_rounded,
                    title: 'Main Office',
                    value: mainOfficeLocation,
                    subtext: 'Central operations, vehicle dispatch & administrative hub',
                  ),
                  _buildHubDetailCard(
                    icon: Icons.phone_in_talk_rounded,
                    title: 'Available Hotlines',
                    value: '$hotline1\n$hotline2',
                    subtext: 'Call or SMS for reservations & roadside assistance',
                    onTap: () => _callPhone(hotline1),
                  ),
                  _buildHubDetailCard(
                    icon: Icons.facebook_rounded,
                    title: 'Official Facebook',
                    value: 'fb.com/psdc.dagupan',
                    subtext: 'Follow us for promos, announcements & updates',
                    onTap: () => _openUrl(facebookUrl),
                  ),
                ],
              ),
              const SizedBox(height: 36),

              // Pangasinan Towns Badges
              Container(
                padding: const EdgeInsets.all(24),
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
                      spacing: 10,
                      runSpacing: 10,
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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D224E),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0x33FFFFFF)),
                        ),
                        child: Text(
                          town,
                          style: const TextStyle(
                            color: Color(0xFFE2E8F0),
                            fontSize: 12,
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
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(24),
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
  Widget _buildRateEstimatorSection(bool isDesktop, bool isTablet) {
    return Container(
      key: _estimatorKey,
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: isDesktop ? 80 : 50,
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
                  fontSize: isDesktop ? 36 : 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Calculate transparent estimated rental fees according to PSDC Pangasinan pricing rules.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              ),
              const SizedBox(height: 36),

              // Interactive Estimator Card
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1838),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Wrap(
                  spacing: 32,
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
                              const SizedBox(width: 12),
                              _buildEstimatorPill(
                                selected: _estimatorMode == 'hourly',
                                label: '⏱️ Hourly (12h Min)',
                                onTap: () => setState(() => _estimatorMode = 'hourly'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Vehicle Type
                          const Text('Vehicle Class', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: ['Sedan', 'SUV', 'MPV', 'Van', 'Compact'].map((type) {
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
                          const SizedBox(height: 20),

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
                          const SizedBox(height: 12),

                          // Driver Toggle
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Hire a Professional Driver', style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
                            subtitle: const Text('PHP 1,500.00 / day. (Doorstep delivery is included free with driver)', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                            value: _estimatorWithDriver,
                            activeColor: AppColors.primary,
                            onChanged: (val) => setState(() => _estimatorWithDriver = val),
                          ),

                          // Doorstep Delivery Toggle (Self-Drive only)
                          if (!_estimatorWithDriver) ...[
                            const SizedBox(height: 8),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Doorstep Delivery (Self-Drive)', style: TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w700)),
                              subtitle: const Text('PHP 75.00 / km anywhere in Pangasinan', style: TextStyle(color: Color(0xFF64748B), fontSize: 11)),
                              value: _estimatorDoorstepDelivery,
                              activeColor: AppColors.primary,
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
                        padding: const EdgeInsets.all(24),
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
                                onPressed: _goToLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: const Color(0xFF030A18),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Proceed to Book in App', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5)),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
            fontSize: 12.5,
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
  Widget _buildWhyMobilisSafetySection(bool isDesktop, bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: isDesktop ? 80 : 50,
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
                  fontSize: isDesktop ? 36 : 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 40),

              Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: [
                  _buildFeatureHighlightCard(
                    icon: Icons.gps_fixed_rounded,
                    title: '24/7 Satellite GPS Safety',
                    description: 'Every vehicle is paired with live real-time GPS tracking for passenger and fleet security.',
                  ),
                  _buildFeatureHighlightCard(
                    icon: Icons.assignment_turned_in_rounded,
                    title: 'Digital Pre/Post Inspection',
                    description: 'Full damage checklist and timestamped photo verification protects you against disputed charges.',
                  ),
                  _buildFeatureHighlightCard(
                    icon: Icons.price_check_rounded,
                    title: 'Fixed Transparent Rates',
                    description: 'No hidden surge pricing. Clear hourly half-day and daily rates across all vehicle categories.',
                  ),
                  _buildFeatureHighlightCard(
                    icon: Icons.shield_rounded,
                    title: 'Verified Drivers & Renters',
                    description: 'Strict identity, valid government ID & driver license screenings ensure safe travels.',
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
  }) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(24),
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
  Widget _buildFaqSection(bool isDesktop) {
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
        horizontal: 24,
        vertical: isDesktop ? 80 : 50,
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
                  fontSize: isDesktop ? 36 : 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 36),

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
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    faq['q']!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Icon(
                                  isExpanded ? Icons.remove_circle_outline_rounded : Icons.add_circle_outline_rounded,
                                  color: isExpanded ? AppColors.primary : const Color(0xFF64748B),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (isExpanded)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            child: Text(
                              faq['a']!,
                              style: const TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13.5,
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
  Widget _buildPreFooterCta(bool isDesktop) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 48),
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
                    fontSize: isDesktop ? 36 : 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Instant bookings, GPS protection, and flexible hourly or daily rates throughout Pangasinan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                ),
                const SizedBox(height: 28),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    ElevatedButton(
                      onPressed: _goToSignup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: const Color(0xFF030A18),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Create Free Account', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                    ),
                    OutlinedButton(
                      onPressed: _goToLogin,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Log In to Portal', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
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
  Widget _buildFooterSection(bool isDesktop) {
    return Container(
      key: _contactKey,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: const BoxDecoration(
        color: Color(0xFF020712),
        border: Border(top: BorderSide(color: Color(0x1AFFFFFF))),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Brand & Address
                  Expanded(
                    flex: isDesktop ? 2 : 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Image.asset('assets/icon/logo-black.png', fit: BoxFit.contain),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'MOBILIS PSDC',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Pangasinan’s premier car rental solutions platform. Verified fleet, accredited drivers, and registered vehicle partners.',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.5),
                        ),
                        const SizedBox(height: 14),
                        const Row(
                          children: [
                            Icon(Icons.location_city_rounded, size: 14, color: AppColors.primary),
                            SizedBox(width: 6),
                            Text(
                              mainOfficeLocation,
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Contacts
                  if (isDesktop) ...[
                    const SizedBox(width: 48),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CONTACTS & SUPPORT', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                          const SizedBox(height: 12),
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
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('QUICK ACCESS', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                          const SizedBox(height: 12),
                          InkWell(onTap: _goToLogin, child: const Text('Renter / Driver / Partner Login', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12))),
                          const SizedBox(height: 6),
                          InkWell(onTap: _goToSignup, child: const Text('Register Account', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12))),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () => Navigator.of(context).pushNamed('/terms-and-privacy'),
                            child: const Text('Legal Terms & Privacy Policy', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const Divider(color: Color(0x1AFFFFFF), height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '© 2026 Mobilis PSDC. All rights reserved.',
                    style: TextStyle(color: Color(0xFF475569), fontSize: 11),
                  ),
                  Row(
                    children: [
                      const Text(
                        'Exclusively in Pangasinan, Philippines',
                        style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 8),
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
