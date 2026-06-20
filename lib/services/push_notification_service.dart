import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'notification_permission_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await PushNotificationService().ensureInitialized();
}

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();

  factory PushNotificationService() => _instance;

  PushNotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _firebaseReady = false;

  bool get isReady => _firebaseReady;

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;

    await _initializeFirebase();
    if (!_firebaseReady) return;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _initializeLocalNotifications();
    await _requestPermissions();

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    FirebaseMessaging.instance.onTokenRefresh.listen(_saveTokenForCurrentUser);

    await syncTokenForCurrentUser();
  }

  Future<void> syncTokenForCurrentUser() async {
    if (!_firebaseReady) return;

    final currentUser = AuthService().currentUser;
    if (currentUser == null) return;

    try {
      final token = await _getMessagingToken();
      if (token == null || token.trim().isEmpty) return;
      await _saveToken(
        userId: currentUser.id,
        token: token,
        role: await AuthService().getUserRole(),
      );
    } catch (e) {
      debugPrint('Push token sync failed: $e');
    }
  }

  Future<void> _initializeFirebase() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        _firebaseReady = true;
        return;
      }

      if (kIsWeb) {
        final options = _webOptions;
        if (options == null) {
          debugPrint(
            'Web Firebase config not provided. Push notifications will stay disabled on web.',
          );
          return;
        }
        await Firebase.initializeApp(options: options);
      } else {
        await Firebase.initializeApp();
      }

      _firebaseReady = true;
    } catch (e) {
      debugPrint('Firebase initialization skipped: $e');
      _firebaseReady = false;
    }
  }

  Future<void> _initializeLocalNotifications() async {
    if (kIsWeb) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(settings);
  }

  Future<void> _requestPermissions() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
    } catch (e) {
      debugPrint('FCM permission request failed: $e');
    }

    await NotificationPermissionService().ensurePrompted();
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title =
        notification?.title ?? message.data['title']?.toString() ?? 'Mobilis';
    final body =
        notification?.body ??
        message.data['body']?.toString() ??
        message.data['message']?.toString() ??
        'You have a new notification';

    if (kIsWeb) {
      await NotificationPermissionService().showBrowserNotification(
        title: title,
        body: body,
      );
      return;
    }

    final android = message.notification?.android;
    final androidDetails = AndroidNotificationDetails(
      'mobilis_general',
      'Mobilis Notifications',
      channelDescription: 'General app notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: android?.smallIcon,
    );

    const iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      title.hashCode ^ body.hashCode,
      title,
      body,
      details,
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification opened: ${message.messageId}');
  }

  Future<String?> _getMessagingToken() async {
    if (kIsWeb) {
      final vapidKey = _webVapidKey;
      if (vapidKey.isEmpty) {
        debugPrint(
          'Web VAPID key not provided. Browser push token retrieval skipped.',
        );
        return null;
      }
      return FirebaseMessaging.instance.getToken(vapidKey: vapidKey);
    }
    return FirebaseMessaging.instance.getToken();
  }

  Future<void> _saveTokenForCurrentUser(String token) async {
    final currentUser = AuthService().currentUser;
    if (currentUser == null) return;

    await _saveToken(
      userId: currentUser.id,
      token: token,
      role: await AuthService().getUserRole(),
    );
  }

  Future<void> _saveToken({
    required String userId,
    required String token,
    String? role,
  }) async {
    await Supabase.instance.client.from('user_push_tokens').upsert({
      'user_id': userId,
      'token': token,
      'platform': _platformLabel,
      'role': role,
      'is_active': true,
      'last_seen_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'token');
  }

  FirebaseOptions? get _webOptions {
    const apiKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
    const appId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
    const messagingSenderId = String.fromEnvironment(
      'FIREBASE_WEB_MESSAGING_SENDER_ID',
    );
    const projectId = String.fromEnvironment('FIREBASE_WEB_PROJECT_ID');

    if (apiKey.isEmpty ||
        appId.isEmpty ||
        messagingSenderId.isEmpty ||
        projectId.isEmpty) {
      return null;
    }

    return const FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: String.fromEnvironment('FIREBASE_WEB_AUTH_DOMAIN'),
      storageBucket: String.fromEnvironment('FIREBASE_WEB_STORAGE_BUCKET'),
      measurementId: String.fromEnvironment('FIREBASE_WEB_MEASUREMENT_ID'),
    );
  }

  String get _webVapidKey =>
      const String.fromEnvironment('FIREBASE_WEB_VAPID_KEY');

  String get _platformLabel {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'other';
    }
  }
}
