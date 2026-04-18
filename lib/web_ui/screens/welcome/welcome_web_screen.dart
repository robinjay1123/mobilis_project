import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../mobile_ui/theme/app_colors.dart';
import '../../../mobile_ui/widgets/custom_button.dart';

class WelcomeWebScreen extends StatefulWidget {
  const WelcomeWebScreen({super.key});

  @override
  State<WelcomeWebScreen> createState() => _WelcomeWebScreenState();
}

class _WelcomeWebScreenState extends State<WelcomeWebScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  final List<WelcomePageData> pages = [
    WelcomePageData(
      title: 'DRIVE YOUR DREAM',
      description: 'Your trusted car rental platform for every journey.',
      icon: Icons.directions_car,
    ),
    WelcomePageData(
      title: 'Easy Booking',
      description: 'Book your favorite car in just a few taps.',
      icon: Icons.calendar_today,
    ),
    WelcomePageData(
      title: 'Secure & Safe',
      description: 'All transactions are encrypted and verified.',
      icon: Icons.shield_rounded,
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
      body: Row(
        children: [
          // Left side - Carousel
          Expanded(
            flex: 1,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.1),
                    AppColors.darkBg,
                  ],
                ),
              ),
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: pages.length,
                itemBuilder: (context, index) {
                  return _buildCarouselPage(pages[index]);
                },
              ),
            ),
          ),
          // Right side - Info and actions
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Text(
                    'Mobilis by PSDC',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Professional Car Rental Solutions',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Current page title and description
                  Text(
                    pages[_currentPage].title,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    pages[_currentPage].description,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Dots indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: List.generate(
                      pages.length,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        width: _currentPage == index ? 32 : 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? AppColors.primary
                              : AppColors.borderColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: CustomButton(
                            label: _currentPage == pages.length - 1
                                ? 'Get Started'
                                : 'Next',
                            onPressed: () async {
                              if (_currentPage == pages.length - 1) {
                                // Mark onboarding as complete
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setBool(
                                  'onboarding_completed',
                                  true,
                                );
                                if (mounted) {
                                  Navigator.of(
                                    context,
                                  ).pushReplacementNamed('/login');
                                }
                              } else {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: OutlinedButton(
                            onPressed: () async {
                              // Mark onboarding as complete
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setBool('onboarding_completed', true);
                              if (mounted) {
                                Navigator.of(
                                  context,
                                ).pushReplacementNamed('/signup');
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
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselPage(WelcomePageData page) {
    return Container(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Large icon
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, color: AppColors.primary, size: 100),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class WelcomePageData {
  final String title;
  final String description;
  final IconData icon;

  WelcomePageData({
    required this.title,
    required this.description,
    required this.icon,
  });
}
