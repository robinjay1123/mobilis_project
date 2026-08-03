import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'notification_permission_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('Firebase background init error: $e');
  }

  final notification = message.notification;
  final title =
      notification?.title ?? message.data['title']?.toString() ?? 'Mobilis';
  final body =
      notification?.body ??
      message.data['body']?.toString() ??
      message.data['message']?.toString() ??
      'You have a new notification';

  if (!kIsWeb) {
    try {
      final localNotifications = FlutterLocalNotificationsPlugin();
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings();
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );
      await localNotifications.initialize(settings);

      const androidDetails = AndroidNotificationDetails(
        'mobilis_general',
        'Mobilis Notifications',
        channelDescription: 'General app notifications',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await localNotifications.show(
        title.hashCode ^ body.hashCode,
        title,
        body,
        details,
        payload: jsonEncode({
          ...message.data,
          'type':
              message.data['type'] ?? message.data['notification_type'] ?? '',
          'title': title,
          'message': body,
        }),
      );
    } catch (e) {
      debugPrint('Background local notification display error: $e');
    }
  }
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
  final StreamController<Map<String, dynamic>> _notificationTapController =
      StreamController<Map<String, dynamic>>.broadcast();
  Map<String, dynamic>? _pendingNotificationTap;

  StreamSubscription? _realtimeSubscription;
  final Set<String> _seenNotificationIds = {};
  String? _activeUserId;
  // Tracks the moment this listener session started — only show notifications
  // created AFTER this timestamp to avoid re-alerting on historical rows.
  DateTime? _listenerStartedAt;

  bool get isReady => _firebaseReady;
  Stream<Map<String, dynamic>> get notificationTaps =>
      _notificationTapController.stream;

  Map<String, dynamic>? takePendingNotificationTap() {
    final pending = _pendingNotificationTap;
    _pendingNotificationTap = null;
    return pending;
  }

  Future<void> ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;

    await _initializeLocalNotifications();

    await _initializeFirebase();

    await _requestPermissions();

    if (_firebaseReady) {
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
      FirebaseMessaging.instance.onTokenRefresh.listen(
        _saveTokenForCurrentUser,
      );

      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTap(initialMessage);
      }
    }

    await syncTokenForCurrentUser();
  }

  Future<void> syncTokenForCurrentUser() async {
    final currentUser = AuthService().currentUser;
    if (currentUser == null) return;

    startRealtimeNotificationListener(currentUser.id);

    if (!_firebaseReady) return;

    try {
      final token = await _getMessagingToken();
      if (token == null || token.trim().isEmpty) return;
      await _saveToken(
        userId: currentUser.id,
        token: token,
        role: await AuthService().getUserRole(),
      );
      debugPrint(
        'Push token registered for ${currentUser.id}: ${_maskedToken(token)}',
      );
    } catch (e) {
      debugPrint('Push token sync failed: $e');
    }
  }

  void startRealtimeNotificationListener(String userId) {
    if (_activeUserId == userId && _realtimeSubscription != null) return;
    _realtimeSubscription?.cancel();
    _activeUserId = userId;
    _seenNotificationIds.clear();

    // Record when this session starts — only notifications created AFTER this
    // moment will trigger a local system notification.
    _listenerStartedAt = DateTime.now().subtract(const Duration(seconds: 5));

    try {
      final client = Supabase.instance.client;
      _realtimeSubscription = client
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .listen(
            (rows) {
              final sessionStart = _listenerStartedAt;
              if (sessionStart == null) return;

              for (final row in rows) {
                final id = row['id']?.toString();
                if (id == null) continue;

                // Skip IDs we've already processed in this session
                if (_seenNotificationIds.contains(id)) continue;
                _seenNotificationIds.add(id);

                final isRead = row['is_read'] == true;
                if (isRead) continue; // already read — no alert needed

                final createdAtStr = row['created_at']?.toString();
                final createdAt =
                    createdAtStr != null
                        ? DateTime.tryParse(createdAtStr)?.toLocal()
                        : null;

                // Only alert on notifications created after this session started
                // (avoids re-alerting on all historical unread notifications)
                if (createdAt == null || createdAt.isBefore(sessionStart)) {
                  continue;
                }

                final title =
                    row['title']?.toString() ?? 'Mobilis Notification';
                final message = row['message']?.toString() ?? '';

                debugPrint(
                  'Realtime notification received: $title — $message (id: $id)',
                );

                showSystemNotification(
                  title: title,
                  body: message,
                  payload:
                      row['data'] is Map
                          ? Map<String, dynamic>.from(row['data'])
                          : {},
                );
              }
            },
            onError: (error) {
              debugPrint('Realtime notification stream error: $error');
            },
          );
    } catch (e) {
      debugPrint('Failed to subscribe to realtime notifications: $e');
    }
  }

  Future<void> showSystemNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    if (kIsWeb) {
      await NotificationPermissionService().showBrowserNotification(
        title: title,
        body: body,
      );
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'mobilis_general',
      'Mobilis Notifications',
      channelDescription: 'General app notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      title.hashCode ^ body.hashCode,
      title,
      body,
      details,
      payload: payload != null ? jsonEncode(payload) : null,
    );
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
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.trim().isEmpty) return;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map) {
            _publishNotificationTap(
              decoded.map((key, value) => MapEntry(key.toString(), value)),
            );
          }
        } catch (e) {
          debugPrint('Local notification payload could not be opened: $e');
        }
      },
    );

    final launchDetails =
        await _localNotifications.getNotificationAppLaunchDetails();
    final launchPayload = launchDetails?.notificationResponse?.payload;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchPayload != null &&
        launchPayload.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(launchPayload);
        if (decoded is Map) {
          _publishNotificationTap(
            decoded.map((key, value) => MapEntry(key.toString(), value)),
          );
        }
      } catch (e) {
        debugPrint('Notification launch payload could not be opened: $e');
      }
    }

    const channel = AndroidNotificationChannel(
      'mobilis_general',
      'Mobilis Notifications',
      description: 'Booking, account, message, and trip notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  Future<void> _requestPermissions() async {
    if (_firebaseReady) {
      try {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          badge: true,
          sound: true,
          provisional: false,
        );
        debugPrint('FCM permission status: ${settings.authorizationStatus}');
      } catch (e) {
        debugPrint('FCM permission request failed: $e');
      }
    }

    if (!kIsWeb) {
      try {
        await _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission();
        await _localNotifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, badge: true, sound: true);
      } catch (e) {
        debugPrint('Local notifications permission request failed: $e');
      }
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

    await showSystemNotification(
      title: title,
      body: body,
      payload: {
        ...message.data,
        'type': message.data['type'] ?? message.data['notification_type'] ?? '',
        'title': title,
        'message': body,
      },
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification opened: ${message.messageId}');
    _publishNotificationTap({
      ...message.data,
      'type': message.data['type'] ?? message.data['notification_type'] ?? '',
      'title':
          message.notification?.title ??
          message.data['title']?.toString() ??
          'Notification',
      'message':
          message.notification?.body ??
          message.data['message']?.toString() ??
          message.data['body']?.toString() ??
          '',
    });
  }

  void _publishNotificationTap(Map<String, dynamic> payload) {
    if (_notificationTapController.hasListener) {
      _notificationTapController.add(payload);
    } else {
      _pendingNotificationTap = payload;
    }
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

  String _maskedToken(String token) {
    if (token.length <= 16) return 'registered';
    return '${token.substring(0, 8)}...${token.substring(token.length - 8)}';
  }
}
