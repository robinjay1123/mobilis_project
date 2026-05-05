# Google OAuth Authentication Integration Guide

## Overview
This document describes the Google OAuth authentication implementation for the Mobilis by PSDC Flutter app using Supabase.

## What Was Implemented

### 1. ✅ AuthService Updates (`lib/services/auth_service.dart`)
Added a new `signInWithGoogle()` method that:
- Initiates OAuth flow using Supabase's built-in OAuth support
- Uses the `io.supabase.flutter://login-callback/` redirect URL
- Passes provider name as a **string** (`'google'`)
- Includes proper error handling and logging
- Returns `AuthResponse` for session management

**Method Signature:**
```dart
Future<AuthResponse> signInWithGoogle() async
```

**Key Detail:** The provider is passed as a string `'google'`, not as an enum constant.

### 2. ✅ Login Screen Updates (`lib/mobile_ui/screens/auth/login_screen.dart`)
- **Removed** Apple login button
- **Added** "Continue with Google" button (full-width)
- **Added** `_handleGoogleLogin()` method that:
  - Checks internet connectivity
  - Manages loading state
  - Handles OAuth flow
  - Shows error messages
  - Navigates to dashboard on success

### 3. ✅ Dependencies (`pubspec.yaml`)
Added:
```yaml
url_launcher: ^6.2.0  # For handling OAuth redirects
```

### 4. ✅ Android Deep Linking (`android/app/src/main/AndroidManifest.xml`)
Added intent-filter for deep linking:
```xml
<!-- Deep link intent filter for OAuth callbacks -->
<intent-filter>
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="io.supabase.flutter" android:host="login-callback"/>
</intent-filter>
```

### 5. ✅ iOS URL Scheme (`ios/Runner/Info.plist`)
Added URL scheme configuration:
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

### 6. ✅ Main App Updates (`lib/main.dart`)
- Added deep linking configuration to Supabase initialization
- Updated `AuthWrapper` to listen for auth state changes
- Added automatic navigation to dashboard on OAuth success
- Added proper stream cleanup in dispose method

## How It Works

### Authentication Flow
1. User taps "Continue with Google" button on login screen
2. `_handleGoogleLogin()` checks internet connection
3. `authService.signInWithGoogle()` initiates OAuth flow
4. User is redirected to Google login in browser
5. After authentication, user is redirected back via deep link
6. `AuthStateChanges` stream listener detects sign-in event
7. App automatically navigates to dashboard

### Session Management
- Supabase handles session creation automatically
- Session is persisted in the app's secure storage
- `AuthWrapper` checks session on app startup
- If session exists, user goes directly to dashboard

## Key Features

✅ **Error Handling**
- Network connectivity checks before OAuth initiation
- Graceful error messages for failed authentications
- User cancellation handling

✅ **Modern Best Practices**
- Uses Supabase's native OAuth support (no additional Google Sign-In plugin needed)
- Follows Flutter Material Design guidelines
- Implements proper state management
- Includes comprehensive logging for debugging

✅ **Security**
- Deep linking configured with app-specific scheme
- OAuth credentials never stored locally
- Automatic session cleanup on logout

✅ **User Experience**
- Seamless OAuth flow with browser redirect
- Loading indicators during authentication
- Clear error feedback
- Automatic dashboard navigation after login

## Testing the Implementation

### Prerequisites
1. Google OAuth enabled in your Supabase project
2. Add your app's redirect URLs in Google Cloud Console
3. Run `flutter pub get` to install new dependencies

### Testing Steps

**Android:**
```bash
# Build and run on Android device/emulator
flutter run -d android
```

**iOS:**
```bash
# Install pods and run on iOS device/simulator
cd ios
pod install
cd ..
flutter run -d ios
```

**Manual Testing Checklist:**
- [ ] App loads login screen correctly
- [ ] "Continue with Google" button is visible and properly styled
- [ ] Tapping Google button opens Google login
- [ ] Username/password fields are hidden on Google login screen
- [ ] After Google login, redirected back to app
- [ ] Dashboard loads successfully
- [ ] User profile shows correct Google account info
- [ ] Logout function works correctly
- [ ] Can login again with different Google account
- [ ] Error messages display for network failures
- [ ] App handles browser back button gracefully

## Configuration

### Supabase Setup
1. Go to Supabase Dashboard → Authentication → Providers
2. Enable Google provider
3. Add OAuth Client ID and Secret from Google Cloud Console
4. Add redirect URLs:
   - `https://zmaudwpinfdnlvplzovx.supabase.co/auth/v1/callback`
   - `io.supabase.flutter://login-callback/` (for mobile app)

### Google Cloud Console Setup
1. Create OAuth 2.0 credentials (Web application)
2. Add authorized redirect URIs:
   - `https://zmaudwpinfdnlvplzovx.supabase.co/auth/v1/callback`
3. For native app OAuth, configure Android/iOS SHA-1 fingerprints
4. Get Client ID and Client Secret

## Troubleshooting

### "Invalid redirect URI" Error
- Verify redirect URIs are configured in both Supabase and Google Cloud Console
- Check that deep linking is properly configured on Android/iOS

### App Crashes on OAuth Callback
- Ensure `android:exported="true"` on MainActivity in AndroidManifest.xml
- Check that intent-filter is correctly nested inside `<activity>` tag

### Session Not Persisting
- Verify Supabase initialization includes deep linking options
- Check that `AuthWrapper` is properly listening to auth state changes

### Google Login Button Not Working
- Confirm internet connection is available
- Check that ConnectivityService is properly initialized
- Verify Google OAuth is enabled in Supabase

## Related Files
- `lib/services/auth_service.dart` - OAuth implementation
- `lib/mobile_ui/screens/auth/login_screen.dart` - UI with Google button
- `lib/main.dart` - App initialization and OAuth callback handling
- `pubspec.yaml` - Dependencies
- `android/app/src/main/AndroidManifest.xml` - Android deep linking
- `ios/Runner/Info.plist` - iOS URL scheme

## Next Steps
1. Configure Google OAuth in your Supabase project
2. Update Google Cloud Console with app credentials
3. Test OAuth flow on both Android and iOS
4. Handle user profile data from Google account
5. Implement additional OAuth providers (Apple, GitHub) if needed

## Security Notes
- Never commit Supabase credentials to version control (use environment variables in production)
- Always validate auth state on app startup
- Implement proper session timeouts for security
- Use HTTPS for all authentication communications
- Regularly audit Google Cloud OAuth applications
