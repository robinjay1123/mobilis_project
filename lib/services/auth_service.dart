import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../utils/input_validation.dart';
import 'preferences_service.dart';
import 'user_restriction_service.dart';
import 'verification_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  static String get _placeholderLicenseExpiry => DateTime.now()
      .add(const Duration(days: 365))
      .toIso8601String()
      .split('T')[0];
  static String _placeholderLicenseNumber(String userId) =>
      'PENDING-${userId.replaceAll('-', '').substring(0, 12)}';

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
      if (user == null) {
        debugPrint('❌ No user - role is null');
        return null;
      }

      debugPrint('🔍 Fetching role for user: ${user.id}');

      final response = await supabase
          .from('users')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      final role = response?['role'] as String?;
      final normalizedRole = role?.toLowerCase().trim();
      debugPrint('📋 Raw response: $response');
      debugPrint(
        '✅ User role fetched: "$role" → normalized: "$normalizedRole"',
      );

      if (normalizedRole == null || normalizedRole.isEmpty) {
        debugPrint('⚠️ WARNING: Role is null or empty!');
        return null;
      }

      return normalizedRole;
    } on PostgrestException catch (e) {
      debugPrint('❌ Database error fetching user role: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching user role: $e');
      return null;
    }
  }

  // Get application status for partner/driver onboarding
  Future<String?> getApplicationStatus() async {
    try {
      final user = currentUser;
      if (user == null) return null;

      final response = await supabase
          .from('users')
          .select('application_status')
          .eq('id', user.id)
          .maybeSingle();

      return response?['application_status'] as String?;
    } on PostgrestException catch (e) {
      debugPrint('Database error fetching application status: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Error fetching application status: $e');
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

      if (newRole == 'partner' || newRole == 'driver') {
        await supabase
            .from('users')
            .update({'application_status': 'pending'})
            .eq('id', user.id);
      }

      if (newRole == 'partner') {
        await _ensurePartnerProfileExists(user.id);
      }

      if (newRole == 'driver') {
        await _ensureDriverProfileExists(user.id);
      }

      if (newRole == 'operator') {
        await _ensureOperatorProfileExists(user.id);
      }

      if (newRole == 'renter') {
        await _ensureRenterProfileExists(user.id);
      }

      debugPrint('User role updated to: $newRole');
    } on PostgrestException catch (e) {
      debugPrint('Database error updating user role: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error updating user role: $e');
      rethrow;
    }
  }

  Future<void> _ensurePartnerProfileExists(String userId) async {
    try {
      final existing = await supabase
          .from('partners')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) return;

      await supabase.from('partners').insert({
        'user_id': userId,
        'verification_status': 'pending',
      });
    } on PostgrestException catch (e) {
      // Keep role switching working even when partner provisioning fails.
      debugPrint('Partner profile provisioning skipped: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected partner profile provisioning error: $e');
    }
  }

  Future<void> _ensureRenterProfileExists(String userId) async {
    try {
      final existing = await supabase
          .from('renters')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) return;

      await supabase.from('renters').insert({'user_id': userId});
    } on PostgrestException catch (e) {
      // Keep auth/profile flow working even if renters table is not present yet.
      debugPrint('Renter profile provisioning skipped: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected renter profile provisioning error: $e');
    }
  }

  Future<void> _ensureOperatorProfileExists(String userId) async {
    try {
      await supabase
          .from('users')
          .update({'role': 'operator'})
          .eq('id', userId);
    } on PostgrestException catch (e) {
      debugPrint('Operator profile provisioning skipped: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected operator profile provisioning error: $e');
    }
  }

  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    try {
      final user = currentUser;
      if (user == null) return null;

      final response = await supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response == null) {
        return {
          'id': user.id,
          'email': user.email,
          'full_name':
              user.userMetadata?['full_name'] ??
              user.userMetadata?['name'] ??
              user.email,
          'role': user.userMetadata?['role'] ?? 'renter',
          'avatar_url':
              user.userMetadata?['avatar_url'] ?? user.userMetadata?['picture'],
        };
      }

      final profile = Map<String, dynamic>.from(response);
      final metadata = user.userMetadata ?? {};
      final avatarUrl = profile['avatar_url']?.toString().trim();
      final profilePictureUrl = profile['profile_picture_url']
          ?.toString()
          .trim();
      profile['avatar_url'] = avatarUrl?.isNotEmpty == true
          ? avatarUrl
          : metadata['avatar_url'] ??
                metadata['profile_picture_url'] ??
                metadata['picture'];
      profile['profile_picture_url'] = profilePictureUrl?.isNotEmpty == true
          ? profilePictureUrl
          : metadata['profile_picture_url'] ??
                metadata['avatar_url'] ??
                metadata['picture'];
      return profile;
    } catch (e) {
      debugPrint('Error fetching current user profile: $e');
      final user = currentUser;
      if (user == null) return null;
      final metadata = user.userMetadata ?? const <String, dynamic>{};
      return {
        'id': user.id,
        'email': user.email,
        'full_name': metadata['full_name'] ?? metadata['name'] ?? user.email,
        'role': metadata['role'] ?? 'renter',
        'avatar_url':
            metadata['avatar_url'] ??
            metadata['profile_picture_url'] ??
            metadata['picture'],
        'profile_picture_url':
            metadata['profile_picture_url'] ??
            metadata['avatar_url'] ??
            metadata['picture'],
      };
    }
  }

  Future<void> _ensureDriverProfileExists(String userId) async {
    try {
      final existing = await supabase
          .from('drivers')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) return;

      await supabase.from('drivers').insert({
        'user_id': userId,
        'license_number': _placeholderLicenseNumber(userId),
        'license_expiry': _placeholderLicenseExpiry,
        'license_verified': false,
        'nbi_verified': false,
        'verification_status': 'pending',
        'driver_tier': 'standard',
        'rating': 0.0,
        'total_trips': 0,
      });
    } on PostgrestException catch (e) {
      // Keep role switching working even when driver provisioning fails.
      debugPrint('Driver profile provisioning skipped: ${e.message}');
    } catch (e) {
      debugPrint('Unexpected driver profile provisioning error: $e');
    }
  }

  // Update user verification details
  Future<void> updateUserVerification({
    required String fullName,
    required String idType,
    required String idNumber,
    required String location,
    required String phone,
    String? idDocumentUrl,
  }) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('No user logged in');

      final normalizedFullName = toTitleCaseName(fullName);
      final normalizedPhone = normalizePhilippineMobile(phone);
      final nameError = validatePersonName(normalizedFullName);
      final phoneError = validatePhilippineMobile(normalizedPhone);
      if (nameError != null) throw Exception(nameError);
      if (phoneError != null) throw Exception(phoneError);

      final blockedMatch = await UserRestrictionService()
          .findBlockedIdentityMatch(
            email: user.email,
            phone: normalizedPhone,
            fullName: normalizedFullName,
          );
      if (blockedMatch != null) {
        await UserRestrictionService().markUserAsBlockedMatch(
          userId: user.id,
          matchedBlockedUserId: blockedMatch['id']?.toString() ?? '',
          reason:
              'Verification was automatically rejected because this identity matches a permanently blocked user.',
        );
        throw Exception(
          'Verification was automatically rejected because this identity matches a blocked user record.',
        );
      }

      debugPrint('Updating verification for user: ${user.id}');

      final updatePayloads = <Map<String, dynamic>>[
        {
          'full_name': normalizedFullName,
          'location': location,
          'phone': normalizedPhone,
          'id_verified': false,
          'verification_status': 'pending',
        },
        {
          'full_name': normalizedFullName,
          'phone': normalizedPhone,
          'id_verified': false,
          'verification_status': 'pending',
        },
        {
          'full_name': normalizedFullName,
          'phone_number': normalizedPhone,
          'id_verified': false,
          'verification_status': 'pending',
        },
        {
          'name': normalizedFullName,
          'phone_number': normalizedPhone,
          'id_verified': false,
          'verification_status': 'pending',
        },
        {
          'name': normalizedFullName,
          'phone': normalizedPhone,
          'id_verified': false,
          'verification_status': 'pending',
        },
        {'id_verified': false, 'verification_status': 'pending'},
      ];

      PostgrestException? lastSchemaError;
      var updated = false;
      for (final payload in updatePayloads) {
        try {
          await supabase.from('users').update(payload).eq('id', user.id);
          updated = true;
          break;
        } on PostgrestException catch (e) {
          lastSchemaError = e;
        }
      }

      if (!updated) {
        throw lastSchemaError ??
            PostgrestException(
              message: 'Unable to update users verification fields',
            );
      }

      if (idDocumentUrl != null && idDocumentUrl.isNotEmpty) {
        await supabase.from('user_verifications').upsert({
          'user_id': user.id,
          'full_name': normalizedFullName,
          'id_type': idType,
          'id_number': idNumber,
          'location': location,
          'phone': normalizedPhone,
          'id_document_url': idDocumentUrl,
          'verification_status': 'pending',
        }, onConflict: 'user_id');
      }

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

  // Update partner/driver application status
  Future<void> updateUserApplicationStatus({required String status}) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('No user logged in');

      debugPrint('Updating application status for user: ${user.id}');

      await supabase
          .from('users')
          .update({'application_status': status})
          .eq('id', user.id);

      debugPrint('Application status updated to: $status');
    } on PostgrestException catch (e) {
      debugPrint('Database error updating application status: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Error updating application status: $e');
      rethrow;
    }
  }

  // Check if partner/driver has been approved by admin
  Future<bool> isApplicationApproved() async {
    try {
      final user = currentUser;
      if (user == null) return false;

      final verificationState =
          await VerificationService.getUserVerificationState(user.id);
      final isVerified = verificationState['is_verified'] == true;

      final response = await supabase
          .from('users')
          .select('role, application_status, id_verified')
          .eq('id', user.id)
          .maybeSingle();

      final role = response?['role']?.toString().trim().toLowerCase();
      final status = response?['application_status']
          ?.toString()
          .trim()
          .toLowerCase();
      final idVerified = response?['id_verified'] == true;

      if ((role == 'partner' || role == 'driver') &&
          (idVerified || isVerified)) {
        return true;
      }

      return status == 'approved';
    } on PostgrestException catch (e) {
      debugPrint('Database error checking application approval: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('Error checking application approval: $e');
      return false;
    }
  }

  // Check if user is verified for rental
  Future<bool> isUserVerified() async {
    try {
      final user = currentUser;
      if (user == null) return false;

      debugPrint('Checking verification status for user: ${user.id}');

      final verificationState =
          await VerificationService.getUserVerificationState(user.id);
      final isVerified = verificationState['is_verified'] as bool? ?? false;
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
    bool rememberDevice = false,
  }) async {
    try {
      debugPrint('Attempting login for: $email');

      final response = await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Backfill public.users row for accounts that exist in auth but failed
      // profile upsert due schema mismatch during signup.
      if (response.user != null) {
        final meta = response.user!.userMetadata ?? <String, dynamic>{};

        // Check existing user profile to preserve their role
        String? userRole;
        final existingProfile = await supabase
            .from('users')
            .select('role')
            .eq('id', response.user!.id)
            .maybeSingle();
        try {
          final existingRole = existingProfile?['role']?.toString().trim();
          if (existingRole != null && existingRole.isNotEmpty) {
            userRole = existingRole;
            debugPrint('📋 [Login] Preserving existing role: $userRole');
          } else if ((meta['role']?.toString().trim() ?? '').isNotEmpty) {
            userRole = meta['role'].toString().trim();
            debugPrint('📋 [Login] Using metadata role: $userRole');
          }
        } catch (e) {
          debugPrint(
            '⚠️ [Login] Error checking existing role: $e, using metadata or default',
          );
          final fallbackRole = meta['role']?.toString().trim();
          userRole = (fallbackRole != null && fallbackRole.isNotEmpty)
              ? fallbackRole
              : null;
        }

        try {
          await _createOrUpdateUserProfile(
            userId: response.user!.id,
            email: response.user!.email ?? email,
            fullName:
                (meta['full_name'] ?? meta['name'] ?? meta['display_name'])
                    as String?,
            phone: meta['phone'] as String?,
            location: meta['location'] as String?,
            role: userRole,
          );
        } catch (e) {
          debugPrint('Profile backfill failed after login: $e');
        }

        // Save credentials if remember device is enabled
        if (rememberDevice) {
          try {
            final prefsService = PreferencesService();
            await prefsService.init();
            await prefsService.saveLoginCredentials(
              email: email,
              password: password,
              rememberDevice: true,
            );
            debugPrint('Login credentials cached for future logins');
          } catch (e) {
            debugPrint('Failed to cache login credentials: $e');
          }
        }
      }

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

      final normalizedMetadata = Map<String, dynamic>.from(userMetadata);
      final rawName = normalizedMetadata['full_name']?.toString() ?? '';
      final normalizedName = toTitleCaseName(rawName);
      final normalizedPhone = normalizePhilippineMobile(
        normalizedMetadata['phone']?.toString() ?? '',
      );
      final nameError = validatePersonName(normalizedName);
      final phoneError = validatePhilippineMobile(normalizedPhone);
      if (nameError != null) throw AuthException(nameError);
      if (phoneError != null) throw AuthException(phoneError);
      normalizedMetadata['full_name'] = normalizedName;
      normalizedMetadata['name'] = normalizedName;
      normalizedMetadata['phone'] = normalizedPhone;

      final existingProfile = await supabase
          .from('users')
          .select('id')
          .eq('email', email)
          .maybeSingle();
      if (existingProfile != null) {
        throw const AuthException('User already registered');
      }

      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        data: normalizedMetadata,
        emailRedirectTo: 'io.supabase.flutter://login-callback/',
      );

      debugPrint('Signup successful for: $email');

      // If signup was successful and we have a user, create/update the users table entry
      if (response.user != null) {
        await _createOrUpdateUserProfile(
          userId: response.user!.id,
          email: email,
          fullName: normalizedMetadata['full_name'] as String?,
          phone: normalizedMetadata['phone'] as String?,
          location: normalizedMetadata['location'] as String?,
          role: normalizedMetadata['role'] as String? ?? 'renter',
        );

        final blockedMatch = await UserRestrictionService()
            .findBlockedIdentityMatch(
              email: email,
              phone: normalizedMetadata['phone'] as String?,
              fullName: normalizedMetadata['full_name'] as String?,
            );
        if (blockedMatch != null) {
          await UserRestrictionService().markUserAsBlockedMatch(
            userId: response.user!.id,
            matchedBlockedUserId: blockedMatch['id']?.toString() ?? '',
            reason:
                'Matched a permanently blocked user record during signup review.',
          );
        }
      }

      if (response.session == null) {
        try {
          final loginResponse = await supabase.auth.signInWithPassword(
            email: email,
            password: password,
          );
          return loginResponse;
        } catch (e) {
          debugPrint('Auto-login after signup skipped: $e');
        }
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
    String? role,
  }) async {
    debugPrint('Creating/updating user profile for: $userId with role: $role');

    // Ensure fullName is never null (database constraint)
    final safeName = toTitleCaseName(
      fullName?.isNotEmpty == true ? fullName! : email.split('@').first,
    );

    final payloadVariants = <Map<String, dynamic>>[
      {
        'id': userId,
        'email': email,
        'name': safeName,
        'full_name': safeName,
        'phone': phone,
        'location': location,
        'id_verified': false,
        if (role != null && role.isNotEmpty) 'role': role,
        if (role != null && role.isNotEmpty)
          'application_status': role == 'partner' || role == 'driver'
              ? 'basic'
              : 'none',
      },
      {
        'id': userId,
        'email': email,
        'name': safeName,
        'full_name': safeName,
        'phone': phone,
        'id_verified': false,
        if (role != null && role.isNotEmpty) 'role': role,
        if (role != null && role.isNotEmpty)
          'application_status': role == 'partner' || role == 'driver'
              ? 'basic'
              : 'none',
      },
      {
        'id': userId,
        'email': email,
        'name': safeName,
        'full_name': safeName,
        'id_verified': false,
        if (role != null && role.isNotEmpty) 'role': role,
        if (role != null && role.isNotEmpty)
          'application_status': role == 'partner' || role == 'driver'
              ? 'basic'
              : 'none',
      },
      {
        'id': userId,
        'email': email,
        'name': safeName,
        'full_name': safeName,
        'id_verified': false,
        if (role != null && role.isNotEmpty) 'role': role,
      },
      {'id': userId, 'email': email, 'name': safeName, 'full_name': safeName},
      {'id': userId, 'email': email, 'name': safeName},
    ];

    PostgrestException? lastSchemaError;
    var profileSaved = false;
    for (final payload in payloadVariants) {
      try {
        await supabase.from('users').upsert(payload);
        profileSaved = true;
        break;
      } on PostgrestException catch (e) {
        lastSchemaError = e;
      }
    }

    if (!profileSaved) {
      throw lastSchemaError ??
          PostgrestException(
            message: 'Unable to create or update users profile',
          );
    }

    if (role == 'partner') {
      await _ensurePartnerProfileExists(userId);
    }

    if (role == 'driver') {
      await _ensureDriverProfileExists(userId);
    }

    if (role == 'renter') {
      await _ensureRenterProfileExists(userId);
    }

    debugPrint('User profile created/updated successfully');
  }

  // Sign in with Google OAuth
  Future<bool> signInWithGoogle() async {
    try {
      debugPrint('Attempting Google OAuth login');

      final response = await supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb
            ? Uri.base.origin
            : 'io.supabase.flutter://login-callback/',
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
  Future<void> signOut({bool clearCredentials = false}) async {
    try {
      debugPrint('Signing out user');

      // Optionally clear cached credentials on explicit logout
      if (clearCredentials) {
        try {
          final prefsService = PreferencesService();
          await prefsService.init();
          await prefsService.clearLoginCredentials();
          debugPrint('Cached login credentials cleared');
        } catch (e) {
          debugPrint('Failed to clear cached credentials: $e');
        }
      }

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

  // Send password reset email
  Future<void> resetPassword({
    required String email,
    String? redirectTo,
  }) async {
    try {
      debugPrint('Sending password reset email to: $email');

      // Use provided redirectTo or default based on platform
      final finalRedirectTo =
          redirectTo ??
          (kIsWeb
              ? '${Uri.base.origin}/#/reset-password'
              : 'io.supabase.flutter://reset-password/');

      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: finalRedirectTo,
      );

      debugPrint('Password reset email sent successfully to: $email');
    } on AuthException catch (e) {
      debugPrint('Auth error during password reset: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error during password reset: $e');
      rethrow;
    }
  }

  /// Resolves an email address or Philippine mobile number to the account's
  /// reset email. Phone lookup uses the existing public user profile record.
  Future<String> resolvePasswordResetEmail(String identifier) async {
    final value = identifier.trim();
    if (value.isEmpty) {
      throw const FormatException('Enter your email or mobile number.');
    }

    if (value.contains('@')) {
      final email = value.toLowerCase();
      final isValid = RegExp(
        r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
      ).hasMatch(email);
      if (!isValid) throw const FormatException('Enter a valid email address.');
      return email;
    }

    final canonicalPhone = _canonicalPhilippinePhone(value);
    if (canonicalPhone == null) {
      throw const FormatException(
        'Enter a valid 11-digit Philippine mobile number.',
      );
    }

    final variants = <String>{
      canonicalPhone,
      '+63${canonicalPhone.substring(1)}',
      '63${canonicalPhone.substring(1)}',
      canonicalPhone.substring(1),
    };

    for (final column in const ['phone', 'phone_number']) {
      for (final phone in variants) {
        try {
          final profile = await supabase
              .from('users')
              .select('email')
              .eq(column, phone)
              .limit(1)
              .maybeSingle();
          final email = profile?['email']?.toString().trim() ?? '';
          if (email.isNotEmpty) return email.toLowerCase();
        } on PostgrestException catch (error) {
          // Older deployments use either `phone` or `phone_number`.
          if (error.code != '42703' && error.code != 'PGRST204') rethrow;
          break;
        }
      }
    }

    throw const AuthException(
      'No account with that mobile number was found. Check the number or use your email address.',
    );
  }

  /// Confirms that an identifier belongs to the currently authenticated user.
  Future<bool> matchesCurrentAccountIdentifier(String identifier) async {
    final user = currentUser;
    if (user == null) throw const AuthException('No signed-in user found.');

    final value = identifier.trim();
    if (value.contains('@')) {
      return value.toLowerCase() == (user.email ?? '').trim().toLowerCase();
    }

    final enteredPhone = _canonicalPhilippinePhone(value);
    if (enteredPhone == null) return false;

    final metadataCandidates = [
      user.phone,
      user.userMetadata?['phone'],
      user.userMetadata?['phone_number'],
    ];
    for (final candidate in metadataCandidates) {
      if (_canonicalPhilippinePhone(candidate?.toString() ?? '') ==
          enteredPhone) {
        return true;
      }
    }

    try {
      final profile = await supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      for (final key in const ['phone', 'phone_number']) {
        if (_canonicalPhilippinePhone(profile?[key]?.toString() ?? '') ==
            enteredPhone) {
          return true;
        }
      }
    } on PostgrestException {
      return false;
    }
    return false;
  }

  String? _canonicalPhilippinePhone(String value) {
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('63') && digits.length == 12) {
      digits = '0${digits.substring(2)}';
    } else if (digits.length == 10 && digits.startsWith('9')) {
      digits = '0$digits';
    }
    return RegExp(r'^09\d{9}$').hasMatch(digits) ? digits : null;
  }

  // Update password with token (for password reset flow)
  Future<void> updatePassword({required String newPassword}) async {
    try {
      final user = currentUser;
      if (user == null) throw Exception('No user logged in');

      debugPrint('Updating password for user: ${user.id}');

      await supabase.auth.updateUser(UserAttributes(password: newPassword));

      debugPrint('Password updated successfully for user: ${user.id}');
    } on AuthException catch (e) {
      debugPrint('Auth error during password update: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error during password update: $e');
      rethrow;
    }
  }

  // Get error message from exception
  String getErrorMessage(dynamic error) {
    String errorMessage = 'An error occurred';

    if (error is AuthException) {
      errorMessage = error.message;
    } else if (error is PostgrestException) {
      errorMessage = error.message;
    } else if (error is FormatException) {
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
