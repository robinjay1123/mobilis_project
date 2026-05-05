import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();

  factory PreferencesService() {
    return _instance;
  }

  PreferencesService._internal();

  late SharedPreferences _prefs;

  // Keys for preferences
  static const String _loginEmailKey = 'cached_login_email';
  static const String _loginPasswordKey = 'cached_login_password';
  static const String _loginRememberKey = 'login_remember_device';
  static const String _signupDataPrefix = 'signup_';
  static const String _lastActivityTimeKey = 'last_activity_time';

  // Initialize preferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    debugPrint('PreferencesService initialized');
  }

  // ==================== LOGIN DATA PERSISTENCE ====================

  /// Save login credentials (only if remember device is checked)
  Future<bool> saveLoginCredentials({
    required String email,
    required String password,
    bool rememberDevice = false,
  }) async {
    try {
      debugPrint('Saving login credentials for: $email');
      await Future.wait([
        _prefs.setString(_loginEmailKey, email),
        _prefs.setString(_loginPasswordKey, password),
        _prefs.setBool(_loginRememberKey, rememberDevice),
      ]);
      return true;
    } catch (e) {
      debugPrint('Error saving login credentials: $e');
      return false;
    }
  }

  /// Get cached login email
  String? getCachedLoginEmail() {
    try {
      return _prefs.getString(_loginEmailKey);
    } catch (e) {
      debugPrint('Error getting cached login email: $e');
      return null;
    }
  }

  /// Get cached login password
  String? getCachedLoginPassword() {
    try {
      return _prefs.getString(_loginPasswordKey);
    } catch (e) {
      debugPrint('Error getting cached login password: $e');
      return null;
    }
  }

  /// Check if remember device is enabled
  bool isRememberDeviceEnabled() {
    try {
      return _prefs.getBool(_loginRememberKey) ?? false;
    } catch (e) {
      debugPrint('Error checking remember device: $e');
      return false;
    }
  }

  /// Clear login credentials
  Future<bool> clearLoginCredentials() async {
    try {
      debugPrint('Clearing login credentials');
      await Future.wait([
        _prefs.remove(_loginEmailKey),
        _prefs.remove(_loginPasswordKey),
        _prefs.remove(_loginRememberKey),
      ]);
      return true;
    } catch (e) {
      debugPrint('Error clearing login credentials: $e');
      return false;
    }
  }

  // ==================== SIGNUP FORM DATA PERSISTENCE ====================

  /// Save signup form field data
  Future<bool> saveSignupFormData(String fieldName, String value) async {
    try {
      debugPrint('Saving signup form data: $fieldName');
      final key = '$_signupDataPrefix$fieldName';
      return await _prefs.setString(key, value);
    } catch (e) {
      debugPrint('Error saving signup form data: $e');
      return false;
    }
  }

  /// Get saved signup form field data
  String? getSignupFormData(String fieldName) {
    try {
      final key = '$_signupDataPrefix$fieldName';
      return _prefs.getString(key);
    } catch (e) {
      debugPrint('Error getting signup form data: $e');
      return null;
    }
  }

  /// Save all signup form fields at once
  Future<bool> saveAllSignupFormData(Map<String, String> formData) async {
    try {
      debugPrint('Saving all signup form data');
      for (var entry in formData.entries) {
        await _prefs.setString('$_signupDataPrefix${entry.key}', entry.value);
      }
      return true;
    } catch (e) {
      debugPrint('Error saving all signup form data: $e');
      return false;
    }
  }

  /// Get all saved signup form fields
  Map<String, String> getAllSignupFormData() {
    try {
      final result = <String, String>{};
      for (var key in _prefs.getKeys()) {
        if (key.startsWith(_signupDataPrefix)) {
          final fieldName = key.replaceFirst(_signupDataPrefix, '');
          final value = _prefs.getString(key);
          if (value != null) {
            result[fieldName] = value;
          }
        }
      }
      debugPrint('Retrieved ${result.length} signup form fields');
      return result;
    } catch (e) {
      debugPrint('Error getting all signup form data: $e');
      return {};
    }
  }

  /// Clear all signup form data
  Future<bool> clearSignupFormData() async {
    try {
      debugPrint('Clearing signup form data');
      final keysToRemove = _prefs
          .getKeys()
          .where((key) => key.startsWith(_signupDataPrefix))
          .toList();

      for (var key in keysToRemove) {
        await _prefs.remove(key);
      }
      return true;
    } catch (e) {
      debugPrint('Error clearing signup form data: $e');
      return false;
    }
  }

  // ==================== OPERATOR ACTIVITY TRACKING ====================

  /// Log operator activity locally
  Future<bool> logOperatorActivity({
    required String operatorId,
    required String
    activityType, // 'login', 'logout', 'booking_approved', 'driver_assigned', etc.
    String? description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint(
        'Logging operator activity: $activityType for operator: $operatorId',
      );

      final timestamp = DateTime.now().toIso8601String();
      final activity = {
        'operator_id': operatorId,
        'activity_type': activityType,
        'description': description,
        'timestamp': timestamp,
        'metadata': metadata ?? {},
      };

      // Get existing activities
      final activitiesJson = _prefs.getStringList('operator_activities') ?? [];

      // Add new activity
      // Note: In production, this should be limited to prevent storage bloat
      activitiesJson.add(activity.toString());

      // Keep only last 100 activities locally
      if (activitiesJson.length > 100) {
        activitiesJson.removeRange(0, activitiesJson.length - 100);
      }

      await _prefs.setStringList('operator_activities', activitiesJson);
      await _prefs.setString(_lastActivityTimeKey, timestamp);

      return true;
    } catch (e) {
      debugPrint('Error logging operator activity: $e');
      return false;
    }
  }

  /// Get last operator activity timestamp
  String? getLastActivityTime() {
    try {
      return _prefs.getString(_lastActivityTimeKey);
    } catch (e) {
      debugPrint('Error getting last activity time: $e');
      return null;
    }
  }

  /// Clear all operator activities (after syncing to server)
  Future<bool> clearOperatorActivities() async {
    try {
      debugPrint('Clearing operator activities');
      return await _prefs.remove('operator_activities');
    } catch (e) {
      debugPrint('Error clearing operator activities: $e');
      return false;
    }
  }

  /// Get all stored operator activities
  List<String> getAllOperatorActivities() {
    try {
      return _prefs.getStringList('operator_activities') ?? [];
    } catch (e) {
      debugPrint('Error getting operator activities: $e');
      return [];
    }
  }
}
