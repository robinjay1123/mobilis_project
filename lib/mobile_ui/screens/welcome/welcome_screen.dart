import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  final List<WelcomePageData> pages = [
    WelcomePageData(
      title: 'DRIVE YOUR DREAM',
      description: 'Your trusted car rental platform for every journey.',
      icon: Icons.directions_car_rounded,
      imagePath: 'assets/illustrations/slide_drive_dream.png',
    ),
    WelcomePageData(
      title: 'Easy Booking',
      description: 'Book your favorite car in just a few taps.',
      icon: Icons.calendar_month_rounded,
      imagePath: 'assets/illustrations/slide_easy_booking.png',
    ),
    WelcomePageData(
      title: 'Secure & Safe',
      description: 'All transactions are encrypted and verified.',
      icon: Icons.verified_user_rounded,
      imagePath: 'assets/illustrations/slide_secure_safe.png',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Column(
        children: [
          // Skip button
          Padding(
            padding: const EdgeInsets.only(top: 24, right: 24),
            child: Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () async {
                  // Mark onboarding as complete
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('onboarding_completed', true);
                  if (mounted) {
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                },
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          // Page content
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: pages.length,
              itemBuilder: (context, index) {
                return _buildPage(pages[index], index);
              },
            ),
          ),
          // Dots indicator
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                pages.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? AppColors.primary
                        : AppColors.borderColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              children: [
                CustomButton(
                  label: _currentPage == pages.length - 1
                      ? 'Get Started'
                      : 'Next',
                  onPressed: () async {
                    if (_currentPage == pages.length - 1) {
                      // Mark onboarding as complete
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('onboarding_completed', true);
                      if (mounted) {
                        Navigator.of(context).pushReplacementNamed('/login');
                      }
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () async {
                      // Mark onboarding as complete
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('onboarding_completed', true);
                      if (mounted) {
                        Navigator.of(context).pushReplacementNamed('/signup');
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: AppColors.borderColor,
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Create Account',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
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

  Widget _buildPage(WelcomePageData page, int pageIndex) {
    final isActive = _currentPage == pageIndex;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Image.asset(
                  'assets/icon/logo-black.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Mobilis by PSDC',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _InteractiveCartoonIllustration(
            imagePath: page.imagePath,
            icon: page.icon,
            isActive: isActive,
          ),
          const SizedBox(height: 32),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            page.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class WelcomePageData {
  final String title;
  final String description;
  final IconData icon;
  final String imagePath;

  WelcomePageData({
    required this.title,
    required this.description,
    required this.icon,
    required this.imagePath,
  });
}

class _InteractiveCartoonIllustration extends StatefulWidget {
  final String imagePath;
  final IconData icon;
  final bool isActive;

  const _InteractiveCartoonIllustration({
    required this.imagePath,
    required this.icon,
    required this.isActive,
  });

  @override
  State<_InteractiveCartoonIllustration> createState() =>
      _InteractiveCartoonIllustrationState();
}

class _InteractiveCartoonIllustrationState
    extends State<_InteractiveCartoonIllustration>
    with SingleTickerProviderStateMixin {
  late AnimationController _floatController;
  double _tapScale = 1.0;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  void _onTapDown(_) => setState(() => _tapScale = 0.94);
  void _onTapUp(_) => setState(() => _tapScale = 1.0);
  void _onTapCancel() => setState(() => _tapScale = 1.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _tapScale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedBuilder(
          animation: _floatController,
          builder: (context, child) {
            final dy = (1.0 - _floatController.value) * 8.0;
            return Transform.translate(
              offset: Offset(0, dy),
              child: child,
            );
          },
          child: Container(
            width: 260,
            height: 220,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.6),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                widget.imagePath,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, size: 44, color: Colors.black),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
