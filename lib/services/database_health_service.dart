import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../mobile_ui/widgets/database_unhealthy_modal.dart';

/// Centralized service to monitor database connectivity and health,
/// detect database downtime / unhealthy states, and display the
/// Database Unhealthy Modal to users.
class DatabaseHealthService extends ChangeNotifier {
  static final DatabaseHealthService _instance =
      DatabaseHealthService._internal();

  factory DatabaseHealthService() => _instance;

  DatabaseHealthService._internal();

  /// Global navigator key allowing the modal to be displayed from any service or callback.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  bool _isHealthy = true;
  bool _isModalVisible = false;
  DateTime? _lastModalShownAt;

  bool get isHealthy => _isHealthy;
  bool get isModalVisible => _isModalVisible;

  void setModalVisible(bool visible) {
    _isModalVisible = visible;
    notifyListeners();
  }

  /// Evaluates whether an exception or error represents an unhealthy / degraded database state.
  static bool isDatabaseUnhealthyError(dynamic error) {
    if (error == null) return false;

    // 1. PostgrestException inspection
    if (error is PostgrestException) {
      final code = error.code?.toUpperCase() ?? '';
      final msg = error.message.toLowerCase();
      final details = (error.details?.toString() ?? '').toLowerCase();
      final hint = (error.hint?.toString() ?? '').toLowerCase();

      // PostgreSQL connection and system fault codes
      // 08xxx = Connection Exception
      // 53xxx = Insufficient Resources (too_many_connections, out_of_memory)
      // 57xxx = Operator Intervention (admin_shutdown, cannot_connect_now)
      // 58xxx = System Error
      if (code.startsWith('08') ||
          code.startsWith('53') ||
          code.startsWith('57') ||
          code.startsWith('58')) {
        return true;
      }

      if (_containsUnhealthyKeywords(msg) ||
          _containsUnhealthyKeywords(details) ||
          _containsUnhealthyKeywords(hint)) {
        return true;
      }
    }

    final text = error.toString().toLowerCase();

    // 2. HTTP Server Error codes (500, 502, 503, 504, 520-526)
    if (RegExp(r'\b(500|502|503|504|520|521|522|523|524|525|526)\b')
        .hasMatch(text)) {
      return true;
    }

    // 3. String keywords indicating database server unhealthy state
    return _containsUnhealthyKeywords(text);
  }

  static bool _containsUnhealthyKeywords(String text) {
    return text.contains('database unavailable') ||
        text.contains('database is unhealthy') ||
        text.contains('unhealthy state') ||
        text.contains('upstream connect error') ||
        text.contains('connection refused') ||
        text.contains('connection closed') ||
        text.contains('server error') ||
        text.contains('service unavailable') ||
        text.contains('bad gateway') ||
        text.contains('gateway timeout') ||
        text.contains('too many connections') ||
        text.contains('remaining connection slots are reserved') ||
        text.contains('terminating connection due to administrator command') ||
        text.contains('the database system is starting up') ||
        text.contains('the database system is shutting down') ||
        text.contains('cannot connect now') ||
        text.contains('admin shutdown') ||
        text.contains('deadlock detected') ||
        text.contains('database error');
  }

  /// Handles any error. If it indicates an unhealthy database, shows the modal and returns true.
  static bool handlePossibleDatabaseError(dynamic error,
      [BuildContext? context]) {
    if (isDatabaseUnhealthyError(error)) {
      showUnhealthyModal(context: context);
      return true;
    }
    return false;
  }

  /// Triggers the Database Unhealthy Modal with built-in deduplication and cooldown.
  static void showUnhealthyModal({
    BuildContext? context,
    String? message,
  }) {
    final instance = DatabaseHealthService();
    if (instance.isModalVisible) return;

    // Throttle modal appearances (minimum 10s between dialog presentations)
    final now = DateTime.now();
    if (instance._lastModalShownAt != null &&
        now.difference(instance._lastModalShownAt!) <
            const Duration(seconds: 10)) {
      return;
    }
    instance._lastModalShownAt = now;

    final targetContext = context ?? navigatorKey.currentContext;
    if (targetContext == null) {
      debugPrint(
        '⚠️ [DatabaseHealthService] Unable to show modal: no active context',
      );
      return;
    }

    // Post to next frame to ensure safe presentation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (instance.isModalVisible) return;
      DatabaseUnhealthyModal.show(targetContext, message: message);
    });
  }

  /// Actively tests database responsiveness with a lightweight ping.
  Future<bool> checkHealth() async {
    try {
      final client = Supabase.instance.client;
      // Lightweight select to verify database connection
      await client
          .from('users')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 4));

      _isHealthy = true;
      notifyListeners();
      return true;
    } catch (e) {
      if (isDatabaseUnhealthyError(e)) {
        _isHealthy = false;
        notifyListeners();
        return false;
      }
      // If table query threw an auth or other non-server error, the DB connection itself is alive
      return true;
    }
  }
}
