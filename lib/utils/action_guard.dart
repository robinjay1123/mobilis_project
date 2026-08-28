import 'package:flutter/foundation.dart';

/// Centralized Anti-Spam and Double-Click Protection System.
/// Prevents duplicate concurrent execution of dialog triggers, form submissions, and API actions.
class ActionGuard {
  static final Set<String> _activeActionKeys = <String>{};

  /// Wraps an async or sync callback with anti-spam locking using a unique [key].
  /// If the action is already in progress, subsequent clicks are ignored.
  static VoidCallback? guard(
    String key,
    Future<void> Function()? callback, {
    VoidCallback? onBlocked,
  }) {
    if (callback == null) return null;
    return () async {
      if (_activeActionKeys.contains(key)) {
        debugPrint('[ActionGuard] Blocked duplicate click for key: $key');
        onBlocked?.call();
        return;
      }
      _activeActionKeys.add(key);
      try {
        await callback();
      } finally {
        _activeActionKeys.remove(key);
      }
    };
  }

  /// Runs an async action directly with anti-spam lock protection.
  /// Returns `null` if the action was blocked due to ongoing execution.
  static Future<T?> runGuarded<T>(
    String key,
    Future<T> Function() action, {
    VoidCallback? onBlocked,
  }) async {
    if (_activeActionKeys.contains(key)) {
      debugPrint('[ActionGuard] Blocked duplicate action execution for key: $key');
      onBlocked?.call();
      return null;
    }
    _activeActionKeys.add(key);
    try {
      return await action();
    } catch (e) {
      rethrow;
    } finally {
      _activeActionKeys.remove(key);
    }
  }

  /// Checks if an action key is currently active/running.
  static bool isRunning(String key) => _activeActionKeys.contains(key);
}
