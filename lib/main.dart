import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'mobile_ui/theme/app_theme.dart';
import 'mobile_ui/theme/app_colors.dart';
import 'mobile_ui/widgets/animated_loading.dart';
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
import 'mobile_ui/screens/home/chat_detail_screen.dart';
import 'responsive/responsive_screens.dart';
import 'web_ui/screens/admin/admin_web_screen.dart';
import 'web_ui/screens/operator/operator_web_screen.dart';
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
      home: DoubleBackExitWrapper(
        child: AuthWrapper(
          onThemeToggle: _toggleTheme,
          isDarkMode: _isDarkMode,
        ),
      ),
      routes: {
        '/welcome': (context) => const ResponsiveWelcomeScreen(),
        '/login': (context) => const ResponsiveLoginScreen(),
        '/signup': (context) => const ResponsiveSignupScreen(),
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
        '/dashboard': (context) {
          // Protect dashboard route - redirect to login if not authenticated
          final authService = AuthService();
          if (!authService.isAuthenticated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacementNamed('/login');
            });
            return const ResponsiveLoginScreen();
          }

          // Return dashboard route selector widget that checks role and routes accordingly
          return const DashboardRouteSelector();
        },
        '/partner-home': (context) {
          final authService = AuthService();
          if (!authService.isAuthenticated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacementNamed('/login');
            });
            return const ResponsiveLoginScreen();
          }
          return const PartnerHomeScreen();
        },
        '/apply-vehicle': (context) {
          final authService = AuthService();
          if (!authService.isAuthenticated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacementNamed('/login');
            });
            return const ResponsiveLoginScreen();
          }
          return const ApplyVehicleScreen();
        },
        '/vehicle-availability': (context) {
          final authService = AuthService();
          if (!authService.isAuthenticated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacementNamed('/login');
            });
            return const ResponsiveLoginScreen();
          }
          return const VehicleAvailabilityScreen();
        },
        '/owner-verification': (context) => const OwnerVerificationScreen(),
        '/vehicle-registration-upload': (context) =>
            const VehicleRegistrationUploadScreen(),
        '/verification-success': (context) => const VerificationSuccessScreen(),
        '/operator-home': (context) {
          final authService = AuthService();
          if (!authService.isAuthenticated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacementNamed('/login');
            });
            return const ResponsiveLoginScreen();
          }
          return const OperatorWebScreen();
        },
        '/admin-home': (context) {
          final authService = AuthService();
          if (!authService.isAuthenticated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacementNamed('/login');
            });
            return const ResponsiveLoginScreen();
          }
          return const AdminWebScreen();
        },
        '/vehicle-detail': (context) {
          final authService = AuthService();
          if (!authService.isAuthenticated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacementNamed('/login');
            });
            return const ResponsiveLoginScreen();
          }
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
        '/driver-home': (context) {
          final authService = AuthService();
          if (!authService.isAuthenticated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacementNamed('/login');
            });
            return const ResponsiveLoginScreen();
          }
          return const DriverHomeScreen();
        },
        '/chat-detail': (context) {
          final authService = AuthService();
          if (!authService.isAuthenticated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacementNamed('/login');
            });
            return const ResponsiveLoginScreen();
          }
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          return ChatDetailScreen(
            conversationId: args?['conversationId'] ?? '',
            recipientName: args?['recipientName'] ?? 'Recipient',
            recipientAvatar: args?['recipientAvatar'] ?? '',
            isDarkMode: args?['isDarkMode'] ?? false,
          );
        },
      },
    );
  }
}

class DoubleBackExitWrapper extends StatefulWidget {
  final Widget child;

  const DoubleBackExitWrapper({super.key, required this.child});

  @override
  State<DoubleBackExitWrapper> createState() => _DoubleBackExitWrapperState();
}

class _DoubleBackExitWrapperState extends State<DoubleBackExitWrapper> {
  DateTime? _lastBackPressedAt;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
          return;
        }

        final now = DateTime.now();
        final shouldExit =
            _lastBackPressedAt != null &&
            now.difference(_lastBackPressedAt!) < const Duration(seconds: 2);

        if (shouldExit) {
          SystemNavigator.pop();
          return;
        }

        _lastBackPressedAt = now;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Press back again to exit'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: widget.child,
    );
  }
}

// Dashboard route selector - checks user role and routes accordingly
class DashboardRouteSelector extends StatefulWidget {
  const DashboardRouteSelector({super.key});

  @override
  State<DashboardRouteSelector> createState() => _DashboardRouteSelectorState();
}

class _DashboardRouteSelectorState extends State<DashboardRouteSelector> {
  @override
  void initState() {
    super.initState();
    _checkRoleAndRoute();
  }

  Future<void> _checkRoleAndRoute() async {
    final authService = AuthService();
    final role = await authService.getUserRole();

    if (!mounted) return;

    debugPrint('📊 [DashboardRouteSelector] User role: $role');

    // Route based on role
    String targetRoute = '/dashboard'; // Default for renter

    if (role == 'admin') {
      targetRoute = '/admin-home';
    } else if (role == 'operator') {
      targetRoute = '/operator-home';
    } else if (role == 'partner') {
      targetRoute = '/partner-home';
    } else if (role == 'driver') {
      targetRoute = '/driver-home';
    }

    if (targetRoute != '/dashboard') {
      debugPrint('🚀 [DashboardRouteSelector] Redirecting to: $targetRoute');
      Navigator.of(context).pushReplacementNamed(targetRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while checking role
    final screenWidth = MediaQuery.of(context).size.width;

    if (kIsWeb || screenWidth > 900) {
      // Web dashboard
      return Scaffold(
        appBar: AppBar(title: const Text('Dashboard')),
        body: const Center(child: Text('Renter Dashboard - Web Version')),
      );
    }

    // Mobile dashboard
    return const DashboardScreen();
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
  RealtimeChannel? _userProfileChannel;
  String? _lastSyncedRoute;

  @override
  void initState() {
    super.initState();
    _initialScreen = _determineInitialScreen();
    _setupAuthListener();
    _setupUserProfileListener();
  }

  void _setupAuthListener() {
    final authService = AuthService();
    _authSubscription = authService.authStateChanges.listen((state) async {
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('🔐 AUTH STATE CHANGED: ${state.event}');
      debugPrint('   User: ${state.session?.user.email}');
      debugPrint('═══════════════════════════════════════════════════════════');
      if (!mounted) return;

      if (state.event == AuthChangeEvent.signedIn &&
          state.session?.user != null) {
        debugPrint('✅ SignedIn event triggered - will sync route in 500ms');
        await Future.delayed(
          Duration(milliseconds: 500),
        ); // Small delay to ensure DB is updated
        await _syncRouteForCurrentUser();
        _setupUserProfileListener();
      }

      if (state.event == AuthChangeEvent.signedOut) {
        debugPrint('🚪 SignedOut event triggered');
        _disposeUserProfileListener();
        _lastSyncedRoute = null;
      }
    });
  }

  void _setupUserProfileListener() {
    final userId = AuthService().currentUser?.id;
    if (userId == null) {
      _disposeUserProfileListener();
      return;
    }

    _disposeUserProfileListener();

    final supabase = Supabase.instance.client;
    _userProfileChannel = supabase
        .channel('public:users:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) async {
            if (!mounted) return;
            await _syncRouteForCurrentUser();
          },
        )
        .subscribe();
  }

  void _disposeUserProfileListener() {
    if (_userProfileChannel != null) {
      Supabase.instance.client.removeChannel(_userProfileChannel!);
      _userProfileChannel = null;
    }
  }

  Future<void> _syncRouteForCurrentUser() async {
    final authService = AuthService();
    final user = authService.currentUser;
    if (!mounted || user == null) {
      debugPrint('❌ _syncRouteForCurrentUser: mounted=$mounted, user=$user');
      return;
    }

    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('🔄 SYNCING ROUTE FOR: ${user.email}');
    debugPrint('═══════════════════════════════════════════════════════════');

    debugPrint('📡 Fetching role from database...');
    final role = await authService.getUserRole();
    debugPrint('✅ Role fetched: "$role" (type: ${role.runtimeType})');

    if (role == null) {
      debugPrint('⚠️  WARNING: Role is NULL!');
    }

    final applicationApproved = role == 'partner' || role == 'driver'
        ? await authService.isApplicationApproved()
        : true;

    final targetRoute = _resolveRoute(role, applicationApproved);
    debugPrint('📍 Target route resolved: $targetRoute');

    if (_lastSyncedRoute == targetRoute) {
      debugPrint('⏭️  Already synced to this route, skipping navigation');
      return;
    }

    _lastSyncedRoute = targetRoute;
    debugPrint('🚀 Navigating to: $targetRoute');

    try {
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil(targetRoute, (route) => false);
      debugPrint('✅ Navigation complete');
    } catch (e) {
      debugPrint('❌ Navigation error: $e');
      rethrow;
    }
    debugPrint('═══════════════════════════════════════════════════════════');
  }

  String _resolveRoute(String? role, bool applicationApproved) {
    debugPrint(
      '🔀 Resolving route for role: "$role" (approved: $applicationApproved)',
    );

    if (role == 'admin') {
      debugPrint('✅ Route: ADMIN');
      return '/admin-home';
    }
    if (role == 'operator') {
      debugPrint('✅ Route: OPERATOR');
      return '/operator-home';
    }
    if (role == 'partner') {
      final route = applicationApproved
          ? '/partner-home'
          : '/owner-verification';
      debugPrint('✅ Route: PARTNER ($route)');
      return route;
    }
    if (role == 'driver') {
      final route = applicationApproved
          ? '/driver-home'
          : '/driver-license-upload';
      debugPrint('✅ Route: DRIVER ($route)');
      return route;
    }
    debugPrint('⚠️ Default route: RENTER (role was: "$role")');
    return '/dashboard';
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _disposeUserProfileListener();
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
      debugPrint('🔐 Initial screen - User authenticated with role: $role');
      final applicationApproved = role == 'partner' || role == 'driver'
          ? await authService.isApplicationApproved()
          : true;

      if (role == 'admin') {
        return AdminWebScreen(
          onThemeToggle: widget.onThemeToggle,
          isDarkMode: widget.isDarkMode,
        );
      }

      if (role == 'operator') {
        return OperatorWebScreen(
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
        : const ResponsiveWelcomeScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _initialScreen,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return snapshot.data!;
        }
        // Show animated loading screen while determining initial screen
        return const AnimatedLoadingWidget(
          title: 'Mobilis by PSDC',
          subtitle: 'Professional Car Rental Solutions',
          gifPath: 'assets/loading.gif',
          logoPath: 'assets/icon/logo1.png',
        );
      },
    );
  }
}
