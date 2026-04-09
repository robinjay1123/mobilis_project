import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'mobile_ui/theme/app_theme.dart';
import 'mobile_ui/theme/app_colors.dart';
import 'mobile_ui/screens/welcome/welcome_screen.dart';
import 'mobile_ui/screens/auth/signup_screen.dart';
import 'mobile_ui/screens/auth/email_confirmation_screen.dart';
import 'mobile_ui/screens/auth/face_scan_screen.dart';
import 'mobile_ui/screens/auth/license_upload_screen.dart';
import 'mobile_ui/screens/auth/profile_picture_upload_screen.dart';
import 'mobile_ui/screens/auth/account_verification_screen.dart';
import 'mobile_ui/screens/auth/id_verification_screen.dart';
import 'mobile_ui/screens/auth/verification_options_screen.dart';
import 'mobile_ui/screens/home/dashboard_screen.dart';
import 'mobile_ui/screens/offline/no_internet_screen.dart';
import 'mobile_ui/screens/partner/partner_home_screen.dart';
import 'mobile_ui/screens/partner/apply_vehicle_screen.dart';
import 'mobile_ui/screens/partner/vehicle_availability_screen.dart';
import 'mobile_ui/screens/partner/owner_verification_screen.dart';
import 'mobile_ui/screens/partner/vehicle_registration_upload_screen.dart';
import 'mobile_ui/screens/partner/verification_success_screen.dart';
import 'mobile_ui/screens/vehicle/vehicle_detail_screen.dart';
import 'mobile_ui/screens/driver/driver_license_upload_screen.dart';
import 'mobile_ui/screens/driver/driver_nbi_upload_screen.dart';
import 'mobile_ui/screens/driver/driver_availability_screen.dart';
import 'mobile_ui/screens/driver/driver_home_screen.dart';
import 'responsive/responsive_screens.dart';
import 'services/auth_service.dart';
import 'services/connectivity_service.dart';
import 'services/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: 'https://zmaudwpinfdnlvplzovx.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InptYXVkd3BpbmZkbmx2cGx6b3Z4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzMyMjY3MjAsImV4cCI6MjA4ODgwMjcyMH0.M9ilQpchddyUELFHBf2Touor_fi4_hjlDGij28F1kQc',
    );
    debugPrint('Supabase initialized successfully');
  } catch (e) {
    debugPrint('Supabase initialization error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isOnline = true;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _initializeConnectivity();
    _loadThemePreference();
  }

  void _loadThemePreference() async {
    final isDark = await ThemeService.getIsDarkMode();
    setState(() {
      _isDarkMode = isDark;
    });
  }

  void _toggleTheme(bool isDark) async {
    await ThemeService.setDarkMode(isDark);
    setState(() {
      _isDarkMode = isDark;
    });
  }

  void _initializeConnectivity() async {
    final connectivityService = ConnectivityService();

    // Check initial connectivity
    final isOnline = await connectivityService.checkConnectivity();
    setState(() {
      _isOnline = isOnline;
    });

    // Listen to connectivity changes
    connectivityService.listenConnectivity((isOnline) {
      setState(() {
        _isOnline = isOnline;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOnline) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Mobilis',
        theme: AppTheme.darkTheme,
        home: NoInternetScreen(
          onRetry: () async {
            final connectivityService = ConnectivityService();
            final isOnline = await connectivityService.checkConnectivity();
            setState(() {
              _isOnline = isOnline;
            });
          },
        ),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mobilis',
      theme: _isDarkMode ? AppTheme.darkTheme : AppTheme.lightTheme,
      home: AuthWrapper(onThemeToggle: _toggleTheme, isDarkMode: _isDarkMode),
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const ResponsiveLoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/email-confirmation': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, String>?;
          return EmailConfirmationScreen(email: args?['email'] ?? '');
        },
        '/face-scan': (context) => const FaceScanScreen(),
        '/license-upload': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          return LicenseUploadScreen(step: args?['step'] ?? 1);
        },
        '/profile-picture-upload': (context) =>
            const ProfilePictureUploadScreen(),
        '/account-verification': (context) => const AccountVerificationScreen(),
        '/verification-options': (context) => const VerificationOptionsScreen(),
        '/id-verification': (context) => const IdVerificationScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/partner-home': (context) => const PartnerHomeScreen(),
        '/apply-vehicle': (context) => const ApplyVehicleScreen(),
        '/vehicle-availability': (context) => const VehicleAvailabilityScreen(),
        '/owner-verification': (context) => const OwnerVerificationScreen(),
        '/vehicle-registration-upload': (context) =>
            const VehicleRegistrationUploadScreen(),
        '/verification-success': (context) => const VerificationSuccessScreen(),
        '/operator-home': (context) => const ResponsiveOperatorScreen(),
        '/admin-home': (context) => const ResponsiveAdminScreen(),
        // Dev preview routes - bypass auth for UI testing
        '/preview-operator': (context) => const ResponsiveOperatorScreen(),
        '/preview-admin': (context) => const ResponsiveAdminScreen(),
        // Force specific layouts for testing (regardless of platform)
        '/preview-operator-web': (context) => const PreviewOperatorWeb(),
        '/preview-operator-mobile': (context) => const PreviewOperatorMobile(),
        '/preview-admin-web': (context) => const PreviewAdminWeb(),
        '/preview-admin-mobile': (context) => const PreviewAdminMobile(),
        '/preview-login-web': (context) => const PreviewLoginWeb(),
        '/preview-login-mobile': (context) => const PreviewLoginMobile(),
        '/vehicle-detail': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          return VehicleDetailScreen(
            vehicleId: args?['vehicleId'] ?? '',
            vehicleData: args?['vehicleData'],
          );
        },
        '/driver-license-upload': (context) =>
            const DriverLicenseUploadScreen(),
        '/driver-nbi-upload': (context) => const DriverNBIUploadScreen(),
        '/driver-availability': (context) => const DriverAvailabilityScreen(),
        '/driver-home': (context) => const DriverHomeScreen(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  final Function(bool) onThemeToggle;
  final bool isDarkMode;

  const AuthWrapper({
    super.key,
    required this.onThemeToggle,
    required this.isDarkMode,
  });

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late Future<Widget> _initialScreen;
  late StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _initialScreen = _determineInitialScreen();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    final authService = AuthService();
    _authSubscription = authService.authStateChanges.listen((state) async {
      debugPrint(
        'Auth state changed: ${state.event}, user: ${state.session?.user.email}',
      );
      if (mounted && state.event == AuthChangeEvent.signedIn) {
        // User just signed in via OAuth, check role and navigate accordingly
        if (state.session?.user != null) {
          final role = await authService.getUserRole();
          if (mounted) {
            if (role == 'admin') {
              Navigator.of(context).pushReplacementNamed('/admin-home');
            } else if (role == 'operator') {
              Navigator.of(context).pushReplacementNamed('/operator-home');
            } else if (role == 'partner') {
              Navigator.of(context).pushReplacementNamed('/partner-home');
            } else if (role == 'driver') {
              Navigator.of(context).pushReplacementNamed('/driver-home');
            } else {
              Navigator.of(context).pushReplacementNamed('/dashboard');
            }
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(AuthWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rebuild when theme changes
    if (oldWidget.isDarkMode != widget.isDarkMode) {
      _initialScreen = _determineInitialScreen();
    }
  }

  Future<Widget> _determineInitialScreen() async {
    final authService = AuthService();

    // If user is already logged in, check role and go to appropriate dashboard
    if (authService.isAuthenticated) {
      final role = await authService.getUserRole();

      if (role == 'admin') {
        return ResponsiveAdminScreen(
          onThemeToggle: widget.onThemeToggle,
          isDarkMode: widget.isDarkMode,
        );
      }

      if (role == 'operator') {
        return ResponsiveOperatorScreen(
          onThemeToggle: widget.onThemeToggle,
          isDarkMode: widget.isDarkMode,
        );
      }

      if (role == 'partner') {
        return PartnerHomeScreen(
          onThemeToggle: widget.onThemeToggle,
          isDarkMode: widget.isDarkMode,
        );
      }

      if (role == 'driver') {
        return DriverHomeScreen(
          onThemeToggle: widget.onThemeToggle,
          isDarkMode: widget.isDarkMode,
        );
      }

      // Default to renter dashboard
      return DashboardScreen(
        onThemeToggle: widget.onThemeToggle,
        isDarkMode: widget.isDarkMode,
      );
    }

    // Check if onboarding was already completed
    final prefs = await SharedPreferences.getInstance();
    final onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;

    // If onboarding was completed, go to login screen
    // Otherwise show welcome screen
    return onboardingCompleted
        ? const ResponsiveLoginScreen()
        : const WelcomeScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _initialScreen,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return snapshot.data!;
        }
        // Show loading screen while determining initial screen
        return Scaffold(
          backgroundColor: AppColors.darkBg,
          body: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        );
      },
    );
  }
}
