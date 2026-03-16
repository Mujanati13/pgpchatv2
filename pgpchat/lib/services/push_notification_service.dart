import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final ApiService _api = ApiService();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    try {
      await Firebase.initializeApp();
    } catch (e) {
      debugPrint('[Push] Firebase init skipped: $e');
      return;
    }

    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    await messaging.setAutoInitEnabled(true);

    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('[Push] Foreground message: ${message.messageId}');
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
