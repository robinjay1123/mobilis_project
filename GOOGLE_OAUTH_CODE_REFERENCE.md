# Quick Code Reference - Google OAuth Implementation

## 1. AuthService Method - Google OAuth
**File**: `lib/services/auth_service.dart`

```dart
// Sign in with Google OAuth
Future<AuthResponse> signInWithGoogle() async {
  try {
    debugPrint('Attempting Google OAuth login');

    final response = await supabase.auth.signInWithOAuth(
      'google',  // ← Provider as string, not Provider.google
      redirectTo: 'io.supabase.flutter://login-callback/',
    );

    debugPrint('Google OAuth login successful');
    return response;
  } on AuthException catch (e) {
    debugPrint('Auth error during Google OAuth: ${e.message}');
    rethrow;
  } catch (e) {
    debugPrint('Unexpected error during Google OAuth: $e');
    rethrow;
  }
}
```

## 2. LoginScreen Handler - Google Login
**File**: `lib/mobile_ui/screens/auth/login_screen.dart`

```dart
void _handleGoogleLogin() async {
  // Check internet connection first
  final connectivityService = ConnectivityService();
  if (!connectivityService.isOnline) {
    _showErrorSnackBar(
      'No internet connection. Please check your WiFi or mobile data.',
    );
    return;
  }

  setState(() {
    isLoading = true;
  });

  try {
    final authService = AuthService();
    await authService.signInWithGoogle();

    if (mounted) {
      // Navigate to dashboard
      Navigator.of(context).pushReplacementNamed('/dashboard');
    }
  } catch (e) {
    if (mounted) {
      final authService = AuthService();
      final errorMessage = authService.getErrorMessage(e);
      _showErrorSnackBar(errorMessage);
    }
  } finally {
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }
}
```

## 3. LoginScreen UI - Google Button
**File**: `lib/mobile_ui/screens/auth/login_screen.dart` (in build method)

```dart
// Social login button - replaces both Google and Apple buttons
SizedBox(
  width: double.infinity,
  child: OutlinedButton.icon(
    onPressed: _handleGoogleLogin,
    icon: const Icon(Icons.g_translate, size: 20),
    label: const Text('Continue with Google'),
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 14),
      side: const BorderSide(color: AppColors.borderColor),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  ),
)
```

## 4. Supabase Initialization - Deep Linking
**File**: `lib/main.dart`

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: 'https://zmaudwpinfdnlvplzovx.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
      // Enable deep linking for OAuth callbacks
      deepLinkingOptions: SupabaseDeepLinkingOptions(
        onDeepLink: (session) {
          debugPrint('Deep link callback received with session: ${session?.user.email}');
        },
      ),
    );
  } catch (e) {
    debugPrint('Supabase initialization error: $e');
  }

  runApp(const MyApp());
}
```

## 5. AuthWrapper - Auth State Listening
**File**: `lib/main.dart`

```dart
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
    _authSubscription = authService.authStateChanges.listen((state) {
      debugPrint('Auth state changed: ${state.event}, user: ${state.user?.email}');
      if (mounted && state.event == AuthChangeEvent.signedIn) {
        // User just signed in via OAuth, navigate to dashboard
        if (state.user != null) {
          Navigator.of(context).pushReplacementNamed('/dashboard');
        }
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }
}
```

## 6. Android Deep Linking Configuration
**File**: `android/app/src/main/AndroidManifest.xml`

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    ...>
    <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>
    <!-- Deep link intent filter for OAuth callbacks -->
    <intent-filter>
        <action android:name="android.intent.action.VIEW"/>
        <category android:name="android.intent.category.DEFAULT"/>
        <category android:name="android.intent.category.BROWSABLE"/>
        <data android:scheme="io.supabase.flutter" android:host="login-callback"/>
    </intent-filter>
</activity>
```

## 7. iOS URL Scheme Configuration
**File**: `ios/Runner/Info.plist`

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>io.supabase.flutter</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>io.supabase.flutter</string>
        </array>
    </dict>
</array>
```

## 8. Dependencies Added
**File**: `pubspec.yaml`

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  supabase_flutter: ^2.12.0
  geolocator: ^11.0.0
  geocoding: ^2.1.1
  connectivity_plus: ^6.0.0
  shared_preferences: ^2.2.0
  url_launcher: ^6.2.0  # ← NEW
```

## Integration Checklist

- [x] AuthService: Added `signInWithGoogle()` method
- [x] LoginScreen: Removed Apple button, added Google handler
- [x] LoginScreen: Added `_handleGoogleLogin()` with error handling
- [x] AndroidManifest: Added deep link intent-filter
- [x] Info.plist: Added CFBundleURLTypes and schemes
- [x] pubspec.yaml: Added url_launcher dependency
- [x] main.dart: Added Supabase deep linking options
- [x] main.dart: Added auth state listener in AuthWrapper
- [x] Error handling: Uses existing `ConnectivityService` and `getErrorMessage()`
- [x] Navigation: Auto-navigates to dashboard on OAuth success

## Testing Example

```dart
// To manually test Google OAuth:
1. Run: flutter run
2. Tap "Continue with Google" button
3. Complete Google login in browser
4. App receives OAuth callback via deep link
5. AuthWrapper listens to auth state change
6. Dashboard loads automatically

// To verify session:
final authService = AuthService();
print('Current user: ${authService.currentUser?.email}');
print('Is authenticated: ${authService.isAuthenticated}');
print('Session: ${authService.currentSession}');
```
