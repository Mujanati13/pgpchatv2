import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';

const AndroidNotificationChannel _messagesChannel = AndroidNotificationChannel(
  'messages',
  'Messages',
  description: 'Notifications for incoming chat messages',
  importance: Importance.high,
);

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final ApiService _api = ApiService();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _localNotificationsReady = false;

  Future<void> init() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('[Push] Firebase init skipped: $e');
      return;
    }

    final messaging = FirebaseMessaging.instance;

    await _initLocalNotifications();

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await messaging.setAutoInitEnabled(true);

    FirebaseMessaging.onMessage.listen((message) async {
      debugPrint('[Push] Foreground message: ${message.messageId}');
      await _showForegroundNotification(message);
    });

    messaging.onTokenRefresh.listen((token) async {
      try {
        await _api.updatePushToken(token: token, platform: _platformName());
      } catch (_) {
        // Best-effort update. If unauthenticated, next auth sync will retry.
      }
    });

    _initialized = true;
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    try {
      await _localNotifications.initialize(initSettings);

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_messagesChannel);

      _localNotificationsReady = true;
    } on MissingPluginException {
      // Happens after hot-restart before native plugin registration catches up.
      _localNotificationsReady = false;
      debugPrint(
        '[Push] Local notifications plugin not registered yet; foreground banners disabled for this run.',
      );
    } catch (e) {
      _localNotificationsReady = false;
      debugPrint('[Push] Local notifications init failed: $e');
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    if (!_localNotificationsReady) return;

    final n = message.notification;
    if (n == null) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'messages',
        'Messages',
        channelDescription: 'Notifications for incoming chat messages',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      message.hashCode,
      n.title ?? 'New message',
      n.body ?? 'You received a new message',
      details,
    );
  }

  Future<void> syncTokenWithServer() async {
    if (!_initialized) {
      await init();
      if (!_initialized) return;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;

    await _api.updatePushToken(token: token, platform: _platformName());
  }

  Future<void> unregisterTokenFromServer() async {
    if (!_initialized) return;
    await _api.updatePushToken(token: null, platform: null);
  }

  String _platformName() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }
}
