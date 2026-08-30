import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'mobile_ui/theme/app_theme.dart';
import 'mobile_ui/theme/app_colors.dart';
import 'mobile_ui/widgets/animated_loading.dart';
import 'mobile_ui/screens/auth/email_confirmation_screen.dart';
import 'mobile_ui/screens/auth/face_scan_screen.dart';
import 'mobile_ui/screens/auth/license_upload_screen.dart';
import 'mobile_ui/screens/auth/profile_picture_upload_screen.dart';
import 'mobile_ui/screens/auth/account_verification_screen.dart';
import 'mobile_ui/screens/auth/identity_verification_form_screen.dart';
import 'mobile_ui/screens/auth/verification_options_screen.dart';
import 'mobile_ui/screens/auth/forgot_password_screen.dart';
import 'mobile_ui/screens/auth/reset_password_screen.dart';
import 'mobile_ui/screens/auth/auth_processing_screen.dart';
import 'mobile_ui/screens/home/dashboard_screen.dart';
import 'mobile_ui/screens/profile/legal_terms_privacy_screen.dart';
import 'mobile_ui/screens/offline/no_internet_screen.dart';
import 'mobile_ui/screens/partner/partner_home_screen.dart';
import 'mobile_ui/screens/partner/apply_vehicle_screen.dart';
import 'mobile_ui/screens/partner/vehicle_availability_screen.dart';
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
import 'mobile_ui/screens/operator/operator_mobile_home_screen.dart';
import 'services/auth_service.dart';
import 'services/connectivity_service.dart';
import 'services/notification_permission_service.dart';
import 'services/push_notification_service.dart';
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

  // Non-blocking initialization so Firebase/notification checks never hang app startup
  unawaited(
    PushNotificationService().ensureInitialized().catchError((e) {
      debugPrint('Push notification init error: $e');
    }),
  );

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
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
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
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: DoubleBackExitWrapper(
        child: AuthWrapper(
          onThemeToggle: _toggleTheme,
          isDarkMode: _isDarkMode,
        ),
      ),
      routes: {
        '/welcome': (context) => const ResponsiveWelcomeScreen(),
        '/login': (context) => const ResponsiveLoginScreen(),
        '/auth-processing': (context) {
          final mode = AuthProcessingScreen.modeFromArguments(
            ModalRoute.of(context)?.settings.arguments,
          );
          return AuthProcessingScreen(mode: mode);
        },
        '/forgot-password': (context) => const ForgotPasswordScreen(),
        '/reset-password': (context) => const ResetPasswordScreen(),
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
        '/id-verification': (context) => const IdentityVerificationFormScreen(),
        '/identity-verification-form': (context) =>
            const IdentityVerificationFormScreen(),
        '/terms-and-privacy': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          return LegalTermsPrivacyScreen(
            initialTab: args?['tab']?.toString() ?? 'terms',
            isDarkMode: _isDarkMode,
          );
        },
        '/driver-identity-verification': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          return IdentityVerificationFormScreen(
            userRole: 'driver',
            driverMode: args?['mode']?.toString(),
          );
        },
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
          return DashboardRouteSelector(
            onThemeToggle: _toggleTheme,
            isDarkMode: _isDarkMode,
          );
        },
        '/partner-home': (context) {
          final authService = AuthService();
          if (!authService.isAuthenticated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacementNamed('/login');
            });
            return const ResponsiveLoginScreen();
          }
          return PartnerHomeScreen(
            onThemeToggle: _toggleTheme,
            isDarkMode: _isDarkMode,
          );
        },
        '/apply-vehicle': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          final authService = AuthService();
          if (!authService.isAuthenticated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacementNamed('/login');
            });
            return const ResponsiveLoginScreen();
          }
          return ApplyVehicleScreen(
            startFreshApplication: args?['startFreshApplication'] == true,
          );
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
        '/owner-verification': (context) {
          final args =
              ModalRoute.of(context)?.settings.arguments
                  as Map<String, dynamic>?;
          return IdentityVerificationFormScreen(
            userRole: 'partner',
            viewSubmittedDocuments: args?['viewSubmittedDocuments'] == true,
          );
        },
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
          // Mobile vs Web check
          if (!kIsWeb) {
            return OperatorMobileHomeScreen(
              onThemeToggle: _toggleTheme,
              isDarkMode: _isDarkMode,
            );
          }
          return OperatorWebScreen(
            onThemeToggle: _toggleTheme,
            isDarkMode: _isDarkMode,
          );
        },
        '/admin-home': (context) {
          final authService = AuthService();
          if (!authService.isAuthenticated) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.of(context).pushReplacementNamed('/login');
            });
            return const ResponsiveLoginScreen();
          }
          // Check if running on web
          if (!kIsWeb) {
            return const WebOnlyAccessScreen(role: 'Admin');
          }
          return AdminWebScreen(
            onThemeToggle: _toggleTheme,
            isDarkMode: _isDarkMode,
          );
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
            initialStartDate: args?['initialStartDate'] as DateTime?,
            initialEndDate: args?['initialEndDate'] as DateTime?,
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
          return DriverHomeScreen(
            onThemeToggle: _toggleTheme,
            isDarkMode: _isDarkMode,
          );
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
          final recipientName =
              args?['recipientName']?.toString() ?? 'Recipient';
          final normalizedRecipient = recipientName.trim().toLowerCase();
          final isCustomerService =
              args?['isCustomerService'] == true ||
              normalizedRecipient == 'customer service' ||
              normalizedRecipient == 'admin support';
          return ChatDetailScreen(
            conversationId: args?['conversationId'] ?? '',
            recipientName: recipientName,
            recipientAvatar: args?['recipientAvatar'] ?? '',
            isDarkMode: args?['isDarkMode'] ?? false,
            isAutoGenerated: args?['isAutoGenerated'] == true,
            isCustomerService: isCustomerService,
            userRole: args?['userRole']?.toString() ?? 'renter',
          );
        },
        '/mobile-only-access': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final role = args?['role']?.toString() ?? 'Renter';
          return MobileOnlyAccessScreen(role: role);
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
  final Function(bool)? onThemeToggle;
  final bool isDarkMode;

  const DashboardRouteSelector({
    super.key,
    this.onThemeToggle,
    this.isDarkMode = true,
  });

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
    return DashboardScreen(
      onThemeToggle: widget.onThemeToggle,
      isDarkMode: widget.isDarkMode,
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
  RealtimeChannel? _userProfileChannel;
  String? _lastSyncedRoute;

  @override
  void initState() {
    super.initState();
    _initialScreen = _determineInitialScreen();
    NotificationPermissionService().ensurePrompted();
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

      if (state.event == AuthChangeEvent.passwordRecovery) {
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/reset-password', (route) => false);
        return;
      }

      if (state.event == AuthChangeEvent.signedIn &&
          state.session?.user != null) {
        debugPrint('✅ SignedIn event triggered - will sync route');
        unawaited(NotificationPermissionService().ensurePrompted());
        unawaited(PushNotificationService().syncTokenForCurrentUser());
        await _syncRouteForCurrentUser(force: true);
        _setupUserProfileListener();
      } else if ((state.event == AuthChangeEvent.initialSession ||
              state.event == AuthChangeEvent.tokenRefreshed) &&
          state.session?.user != null) {
        debugPrint('ℹ️ Auth session active (${state.event})');
        unawaited(NotificationPermissionService().ensurePrompted());
        unawaited(PushNotificationService().syncTokenForCurrentUser());
        _setupUserProfileListener();

        // On mobile, or when opening fresh without a synced route, navigate to the user dashboard
        if (!kIsWeb || _lastSyncedRoute == null) {
          _syncRouteForCurrentUser(force: false);
        }
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

  Future<void> _syncRouteForCurrentUser({bool force = false}) async {
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

    if (role == null || role.isEmpty) {
      debugPrint('⚠️ Default route blocked: role is null');
      if (mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      }
      return;
    }

    final applicationApproved = role == 'partner' || role == 'driver'
        ? await authService.isApplicationApproved()
        : true;

    final targetRoute = _resolveRoute(role, applicationApproved);
    debugPrint('📍 Target route resolved: $targetRoute');

    if (!force && _lastSyncedRoute != null) {
      debugPrint('Route sync skipped during in-app navigation');
      return;
    }

    if (_lastSyncedRoute == targetRoute) {
      debugPrint('⏭️  Already synced to this route, skipping navigation');
      return;
    }

    _lastSyncedRoute = targetRoute;
    debugPrint('🚀 Navigating to: $targetRoute');

    try {
      if (mounted) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pushNamedAndRemoveUntil(targetRoute, (route) => false);
        debugPrint('✅ Navigation complete');
      }
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
    if (kIsWeb && (role == 'renter' || role == 'partner' || role == 'driver')) {
      debugPrint('✅ Route: MOBILE ONLY ACCESS ($role)');
      return '/mobile-only-access';
    }
    if (role == 'renter') {
      debugPrint('✅ Route: RENTER');
      return '/dashboard';
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
          : '/driver-identity-verification';
      debugPrint('✅ Route: DRIVER ($route)');
      return route;
    }
    debugPrint('⚠️ Default route: UNAUTHENTICATED (role was: "$role")');
    return '/login';
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
    try {
      final authService = AuthService();

      // If user is already logged in, check role and go to appropriate dashboard
      if (authService.isAuthenticated) {
        final role = await authService.getUserRole().timeout(
          const Duration(seconds: 4),
          onTimeout: () => null,
        );
        debugPrint('🔐 Initial screen - User authenticated with role: $role');
        if (role == null || role.isEmpty) {
          return const ResponsiveLoginScreen();
        }
        final applicationApproved = role == 'partner' || role == 'driver'
            ? await authService.isApplicationApproved().timeout(
                const Duration(seconds: 4),
                onTimeout: () => true,
              )
            : true;

        if (role == 'admin') {
          if (!kIsWeb) {
            return const WebOnlyAccessScreen(role: 'Admin');
          }
          return AdminWebScreen(
            onThemeToggle: widget.onThemeToggle,
            isDarkMode: widget.isDarkMode,
          );
        }

        if (role == 'operator') {
          if (!kIsWeb) {
            return OperatorMobileHomeScreen(
              onThemeToggle: widget.onThemeToggle,
              isDarkMode: widget.isDarkMode,
            );
          }
          return OperatorWebScreen(
            onThemeToggle: widget.onThemeToggle,
            isDarkMode: widget.isDarkMode,
          );
        }

        if (role == 'renter') {
          if (kIsWeb) {
            return const MobileOnlyAccessScreen(role: 'Renter');
          }
          return DashboardScreen(
            onThemeToggle: widget.onThemeToggle,
            isDarkMode: widget.isDarkMode,
          );
        }

        if (role == 'partner') {
          if (kIsWeb) {
            return const MobileOnlyAccessScreen(role: 'Partner');
          }
          if (!applicationApproved) {
            return const IdentityVerificationFormScreen(userRole: 'partner');
          }
          return PartnerHomeScreen(
            onThemeToggle: widget.onThemeToggle,
            isDarkMode: widget.isDarkMode,
          );
        }

        if (role == 'driver') {
          if (kIsWeb) {
            return const MobileOnlyAccessScreen(role: 'Driver');
          }
          if (!applicationApproved) {
            return const IdentityVerificationFormScreen(userRole: 'driver');
          }
          return DriverHomeScreen(
            onThemeToggle: widget.onThemeToggle,
            isDarkMode: widget.isDarkMode,
          );
        }

        return const ResponsiveLoginScreen();
      }

      // On Web, visitors accessing the root URL see the rich public landing page
      if (kIsWeb) {
        return const ResponsiveWelcomeScreen();
      }

      // Check if onboarding was already completed on mobile
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw TimeoutException('Prefs timeout'),
      );
      final onboardingCompleted =
          prefs.getBool('onboarding_completed') ?? false;

      // If onboarding was completed on mobile, go to login screen
      // Otherwise show welcome screen
      return onboardingCompleted
          ? const ResponsiveLoginScreen()
          : const ResponsiveWelcomeScreen();
    } catch (e) {
      debugPrint('⚠️ Error determining initial screen: $e');
      return const ResponsiveWelcomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _initialScreen,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return snapshot.data!;
        }
        if (snapshot.hasError) {
          debugPrint('⚠️ Initial screen FutureBuilder error: ${snapshot.error}');
          return const ResponsiveLoginScreen();
        }
        // Show animated loading screen while determining initial screen
        return const AnimatedLoadingWidget(
          title: 'Mobilis',
          subtitle: 'Car Rental Solutions',
          gifPath: 'assets/loading.gif',
          logoPath: 'assets/icon/logo1.png',
        );
      },
    );
  }
}

// Web-Only Access Screen for admin and operator roles
class WebOnlyAccessScreen extends StatelessWidget {
  final String role;

  const WebOnlyAccessScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.computer,
                    size: 50,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Web Access Only',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  '$role dashboard is only available on web',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.grey[400]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Please access the admin panel at: mobilis.web.com',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: () async {
                    if (context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/auth-processing',
                        (route) => false,
                        arguments: {'mode': 'logout'},
                      );
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
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
}

class MobileOnlyAccessScreen extends StatefulWidget {
  final String role;

  const MobileOnlyAccessScreen({super.key, required this.role});

  @override
  State<MobileOnlyAccessScreen> createState() => _MobileOnlyAccessScreenState();
}

class _MobileOnlyAccessScreenState extends State<MobileOnlyAccessScreen> {
  static const String apkDownloadUrl =
      'https://github.com/robinjay1123/mobilis_project/releases/download/APK/mobilis-app.apk';
  static const String githubReleasesUrl =
      'https://github.com/robinjay1123/mobilis_project/releases';
  bool _downloadTriggered = false;

  @override
  void initState() {
    super.initState();
    // Auto-trigger APK download
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && !_downloadTriggered) {
          _downloadTriggered = true;
          _downloadApk();
        }
      });
    });
  }

  Future<void> _downloadApk() async {
    try {
      final uri = Uri.parse(apkDownloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Auto-download APK error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF030A18),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Container(
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: const Color(0xFF07142E),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0x33FFD740), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    blurRadius: 40,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Android Icon
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.15),
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                    child: const Icon(
                      Icons.android_rounded,
                      size: 48,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'MOBILE APP ONLY • ${widget.role.toUpperCase()}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    'Mobilis for ${widget.role}s is on Mobile',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Description
                  Text(
                    'Your ${widget.role} account is active! Vehicle reservations, digital contracts, live GPS tracking, and trip settlements are exclusive to our official Android mobile app.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13.5,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Auto-download status banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF030D22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your APK download has started automatically. If it didn\'t, tap the button below.',
                            style: TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Download Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _downloadApk,
                      icon: const Icon(Icons.download_rounded, size: 20),
                      label: const Text(
                        'Download Android APK Now',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: const Color(0xFF030A18),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // GitHub Releases Link
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(githubReleasesUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.code_rounded, size: 18, color: Colors.white),
                      label: const Text(
                        'View on GitHub Releases',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0x33FFFFFF)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Navigation links
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                        },
                        icon: const Icon(Icons.home_rounded, size: 16, color: Color(0xFF94A3B8)),
                        label: const Text('Back to Home', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5)),
                      ),
                      const SizedBox(width: 16),
                      TextButton.icon(
                        onPressed: () async {
                          await AuthService().signOut();
                          if (context.mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                          }
                        },
                        icon: const Icon(Icons.logout_rounded, size: 16, color: Color(0xFFEF4444)),
                        label: const Text('Log Out', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12.5)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
