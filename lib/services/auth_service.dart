import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  final supabase = Supabase.instance.client;

  // Get current user
  User? get currentUser => supabase.auth.currentUser;

  // Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  // Get current session
  Session? get currentSession => supabase.auth.currentSession;

  // Listen to auth state changes
  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  // Get user role from users table
  Future<String?> getUserRole() async {
    try {
      final user = currentUser;
      if (user == null) return null;

      debugPrint('Fetching role for user: ${user.id}');

      final response = await supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      final role = response?['role'] as String?;
      debugPrint('User role: $role');
      return role;
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching user role: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Error fetching user role: $e');
      return null;
    }
  }

  // Check if current user is a partner
  Future<bool> isPartner() async {
    final role = await getUserRole();
    return role == 'partner';
  }

  // Check if current user is an operator
  Future<bool> isOperator() async {
    final role = await getUserRole();
    return role == 'operator';
  }

  // Check if current user is an admin
  Future<bool> isAdmin() async {
    final role = await getUserRole();
    return role == 'admin';
  }

  // Update user role
  Future<void> updateUserRole(String newRole) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('No user logged in');

      debugPrint('Updating role for user: ${user.id} to $newRole');

      await supabase.from('users').update({'role': newRole}).eq('id', user.id);

      debugPrint('User role updated to: $newRole');
    } on PostgrestException catch (e) {
      debugPrint('Database error updating user role: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error updating user role: $e');
      rethrow;
    }
  }

  // Update user verification details
  Future<void> updateUserVerification({
    required String fullName,
    required String idType,
    required String idNumber,
    required String location,
    required String phone,
  }) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('No user logged in');

      debugPrint('Updating verification for user: ${user.id}');

      await supabase
          .from('users')
          .update({
            'full_name': fullName,
            'id_type': idType,
            'id_number': idNumber,
            'location': location,
            'phone': phone,
            'id_verified': true,
          })
          .eq('id', user.id);

      debugPrint('User verification updated');
    } on PostgrestException catch (e) {
      debugPrint('Database error updating user verification: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error updating user verification: $e');
      rethrow;
    }
  }

  // Check if user needs ID verification
  Future<bool> needsIdVerification() async {
    try {
      final user = currentUser;
      if (user == null) return false;

      debugPrint('Checking ID verification status for user: ${user.id}');

      final response = await supabase
          .from('users')
          .select('id_verified')
          .eq('id', user.id)
          .maybeSingle();

      final isVerified = response?['id_verified'] as bool? ?? false;
      debugPrint('User ID verified status: $isVerified');

      return !isVerified;
    } on PostgrestException catch (e) {
      debugPrint('Database error checking verification: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error checking verification: $e');
      return false;
    }
  }

  // Check if user logged in via Google
  Future<bool> isGoogleUser() async {
    try {
      final user = currentUser;
      if (user == null) return false;

      debugPrint('Checking if user is Google user: ${user.id}');

      // Check if user has a provider (Google OAuth)
      final providers = user.identities ?? [];
      final isGoogle = providers.any(
        (identity) => identity.provider == 'google',
      );

      debugPrint('User is Google user: $isGoogle');
      return isGoogle;
    } catch (e) {
      debugPrint('Error checking Google user status: $e');
      return false;
    }
  }

  // Update user verification status (for skip verification)
  Future<void> updateUserVerificationStatus({required bool verified}) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('No user logged in');

      debugPrint('Updating verification status for user: ${user.id}');

      await supabase
          .from('users')
          .update({'id_verified': verified})
          .eq('id', user.id);

      debugPrint('User verification status updated to: $verified');
    } on PostgrestException catch (e) {
      debugPrint('Database error updating verification status: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error updating verification status: $e');
      rethrow;
    }
  }

  // Check if user is verified for rental
  Future<bool> isUserVerified() async {
    try {
      final user = currentUser;
      if (user == null) return false;

      debugPrint('Checking verification status for user: ${user.id}');

      final response = await supabase
          .from('users')
          .select('id_verified')
          .eq('id', user.id)
          .maybeSingle();

      final isVerified = response?['id_verified'] as bool? ?? false;
      debugPrint('User verification status: $isVerified');
      return isVerified;
    } on PostgrestException catch (e) {
      debugPrint('Database error checking user verification: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error checking user verification: $e');
      return false;
    }
  }

  // Login with email and password
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('Attempting login for: $email');

      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      debugPrint('Login successful for: $email');
      return response;
    } on AuthException catch (e) {
      debugPrint('Auth error during login: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error during login: $e');
      rethrow;
    }
  }

  // Sign up with email and password
  Future<AuthResponse> signup({
    required String email,
    required String password,
    required Map<String, dynamic> userMetadata,
  }) async {
    try {
      debugPrint('Attempting signup for: $email');

      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: userMetadata,
        emailRedirectTo: 'io.supabase.flutter://login-callback/',
      );

      debugPrint('Signup successful for: $email');

      // If signup was successful and we have a user, create/update the users table entry
      if (response.user != null) {
        await _createOrUpdateUserProfile(
          userId: response.user!.id,
          email: email,
          fullName: userMetadata['full_name'] as String?,
          phone: userMetadata['phone'] as String?,
          location: userMetadata['location'] as String?,
          role: userMetadata['role'] as String? ?? 'renter',
        );
      }

      return response;
    } on AuthException catch (e) {
      debugPrint('Auth error during signup: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error during signup: $e');
      rethrow;
    }
  }

  // Create or update user profile in users table
  Future<void> _createOrUpdateUserProfile({
    required String userId,
    required String email,
    String? fullName,
    String? phone,
    String? location,
    required String role,
  }) async {
    try {
      debugPrint(
        'Creating/updating user profile for: $userId with role: $role',
      );

      await supabase.from('users').upsert({
        'id': userId,
        'email': email,
        'full_name': fullName,
        'phone': phone,
        'location': location,
        'role': role,
        'id_verified': false,
      });

      debugPrint('User profile created/updated successfully');
    } on PostgrestException catch (e) {
      debugPrint('Database error creating user profile: ${e.message}');
      // Don't rethrow - user was created in auth, profile creation can fail silently
    } catch (e) {
      debugPrint('Error creating user profile: $e');
    }
  }

  // Sign in with Google OAuth
  Future<bool> signInWithGoogle() async {
    try {
      debugPrint('Attempting Google OAuth login');

      final response = await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
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

  // Sign out
  Future<void> signOut() async {
    try {
      debugPrint('Signing out user');
      await supabase.auth.signOut();
      debugPrint('Sign out successful');
    } on AuthException catch (e) {
      debugPrint('Auth error during signout: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error during signout: $e');
      rethrow;
    }
  }

  // Verify connection to Supabase
  Future<bool> verifyConnection() async {
    try {
      // Try a simple query to verify connection
      await supabase
          .from('_status')
          .select()
          .limit(1)
          .timeout(const Duration(seconds: 5));
      debugPrint('Supabase connection verified');
      return true;
    } catch (e) {
      debugPrint('Supabase connection error: $e');
      return false;
    }
  }

  // Get error message from exception
  String getErrorMessage(dynamic error) {
    String errorMessage = 'An error occurred';

    if (error is AuthException) {
      errorMessage = error.message;
    } else if (error is PostgrestException) {
      errorMessage = error.message;
    } else {
      errorMessage = error.toString();
    }

    // Clean up error messages
    if (errorMessage.contains('Invalid login credentials')) {
      return 'Invalid email or password';
    } else if (errorMessage.contains('User already registered')) {
      return 'This email is already registered';
    } else if (errorMessage.contains('Email not confirmed')) {
      return 'Email not confirmed';
    } else if (errorMessage.contains('Password should be')) {
      return 'Password must be at least 6 characters';
    } else if (errorMessage.contains('Unable to validate')) {
      return 'Please enter a valid email address';
    } else if (errorMessage.contains('Network') ||
        errorMessage.contains('Connection') ||
        errorMessage.contains('refused')) {
      return 'Network connection error. Please check your internet connection.';
    } else if (errorMessage.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    return errorMessage;
  }
}
