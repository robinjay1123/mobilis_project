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

      // Explicitly reject query syntax, constraint, schema, or missing-entity codes
      // 42xxx = Syntax Error or Access Rule Violation (e.g. 42703 undefined_column, 42P01 undefined_table)
      // 23xxx = Integrity Constraint Violation (e.g. 23505 unique_violation, 23503 foreign_key_violation)
      // 22xxx = Data Exception (e.g. invalid_text_representation)
      // 28xxx = Invalid Authorization Specification
      // PGRSTxxx = PostgREST client/schema errors (e.g. PGRST116, PGRST205, PGRST100)
      if (code.startsWith('42') ||
          code.startsWith('23') ||
          code.startsWith('22') ||
          code.startsWith('28') ||
          code.startsWith('PGRST')) {
        return false;
      }

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

      return false;
    }

    final text = error.toString().toLowerCase();

    // 2. HTTP Server Error codes (502, 503, 504, 520-526, or 500 internal server error)
    if (RegExp(r'\b(502|503|504|520|521|522|523|524|525|526)\b').hasMatch(text) &&
        (text.contains('http') ||
            text.contains('status') ||
            text.contains('gateway') ||
            text.contains('server') ||
            text.contains('cloudflare') ||
            text.contains('supabase'))) {
      return true;
    }

    if (text.contains('500 internal server error') ||
        text.contains('internal server error') ||
        text.contains('status: 500') ||
        text.contains('statuscode: 500') ||
        text.contains('code: 500') ||
        text.contains('code: "500"')) {
      return true;
    }

    // 3. String keywords indicating database server unhealthy state
    return _containsUnhealthyKeywords(text);
  }

  static bool _containsUnhealthyKeywords(String text) {
    return text.contains('database unavailable') ||
        text.contains('database is unhealthy') ||
        text.contains('database health: unhealthy') ||
        text.contains('unhealthy state') ||
        text.contains('upstream connect error') ||
        text.contains('connection refused') ||
        text.contains('failed to connect to postgres') ||
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
        text.contains('deadlock detected');
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
      // Lightweight select on public table to verify database connection
      await client
          .from('vehicles')
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
      // If table query threw a non-downtime error, the DB connection itself is alive
      return true;
    }
  }
}
