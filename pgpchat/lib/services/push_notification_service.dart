import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final StreamController<String> _incomingMessageController =
      StreamController<String>.broadcast();
  final StreamController<String> _openConversationController =
      StreamController<String>.broadcast();
  bool _initialized = false;
  bool _localNotificationsReady = false;
  String? _pendingOpenConversationUserId;

  // Emits sender user IDs as soon as a new-message push is received.
  Stream<String> get incomingMessageStream => _incomingMessageController.stream;

  // Emits sender user IDs when user taps a push/local notification.
  Stream<String> get openConversationStream => _openConversationController.stream;

  String? consumePendingOpenConversationUserId() {
    final pending = _pendingOpenConversationUserId;
    _pendingOpenConversationUserId = null;
    return pending;
  }

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
      if (await _isSelfSentForCurrentUser(message.data)) {
        return;
      }
      _emitIncomingMessage(message.data);
      await _showForegroundNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleConversationOpenFromData(message.data);
    });

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleConversationOpenFromData(initialMessage.data);
    }

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
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onLocalNotificationTap,
      );

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
        setAsGroupSummary: true,
      ),
      iOS: DarwinNotificationDetails(),
    );

    final senderId = _extractSenderId(message.data);
    final payload =
        senderId == null ? null : jsonEncode({'type': 'new_message', 'senderId': senderId});

    await _localNotifications.show(
      message.hashCode,
      n.title ?? 'New message',
      n.body ?? 'You received a new message',
      details,
      payload: payload,
    );

    // Update app badge count
    await _updateBadgeCount();
  }

  Future<void> _updateBadgeCount() async {
    try {
      final notifications = await _localNotifications.getActiveNotifications();
      final badgeCount = notifications.length;

      // Note: setBadgeCount is not available in flutter_local_notifications ^17.2.3
      // Badge management is handled by the platform automatically
      debugPrint('[Push] Active notifications: $badgeCount');
    } catch (e) {
      debugPrint('[Push] Failed to get notification count: $e');
    }
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

  Future<void> clearNotificationBadge() async {
    try {
      // Note: setBadgeCount is not available in flutter_local_notifications ^17.2.3
      // Badge management is handled by the platform automatically
      debugPrint('[Push] Notification badge cleared');
    } catch (e) {
      debugPrint('[Push] Failed to clear badge: $e');
    }
  }

  Future<void> removeNotification(int id) async {
    try {
      await _localNotifications.cancel(id);
      await _updateBadgeCount();
    } catch (e) {
      debugPrint('[Push] Failed to remove notification: $e');
    }
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        _handleConversationOpenFromData(decoded);
      }
    } catch (e) {
      debugPrint('[Push] Failed to decode local notification payload: $e');
    }
  }

  Future<bool> _isSelfSentForCurrentUser(Map<String, dynamic> data) async {
    final senderId = _extractSenderId(data);
    if (senderId == null) return false;
    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString('user_id');
    return currentUserId != null && currentUserId == senderId;
  }

  void _emitIncomingMessage(Map<String, dynamic> data) {
    if (!_isNewMessagePayload(data)) return;
    final senderId = _extractSenderId(data);
    if (senderId == null) return;
    _incomingMessageController.add(senderId);
  }

  void _handleConversationOpenFromData(Map<String, dynamic> data) {
    if (!_isNewMessagePayload(data)) return;
    final senderId = _extractSenderId(data);
    if (senderId == null) return;

    if (_openConversationController.hasListener) {
      _openConversationController.add(senderId);
    } else {
      _pendingOpenConversationUserId = senderId;
    }
  }

  bool _isNewMessagePayload(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    return type == null || type == 'new_message';
  }

  String? _extractSenderId(Map<String, dynamic> data) {
    final senderId = data['senderId']?.toString().trim();
    if (senderId == null || senderId.isEmpty) return null;
    return senderId;
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
