import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/web_html.dart' as html;

class NotificationPermissionService {
  static final NotificationPermissionService _instance =
      NotificationPermissionService._internal();

  factory NotificationPermissionService() => _instance;

  NotificationPermissionService._internal();

  static const String _promptedKey = 'browser_notification_prompted';

  Future<void> ensurePrompted() async {
    if (!kIsWeb) return;

    final prefs = await SharedPreferences.getInstance();
    final prompted = prefs.getBool(_promptedKey) ?? false;
    if (prompted) return;

    try {
      await html.Notification.requestPermission();
    } catch (e) {
      debugPrint('Browser notification permission request failed: $e');
    }

    await prefs.setBool(_promptedKey, true);
  }

  Future<void> showBrowserNotification({
    required String title,
    required String body,
  }) async {
    if (!kIsWeb) return;

    try {
      final permission = await html.Notification.requestPermission();
      if (permission != 'granted') return;
      html.Notification(title, body: body);
    } catch (e) {
      debugPrint('Browser notification display failed: $e');
    }
  }
}
