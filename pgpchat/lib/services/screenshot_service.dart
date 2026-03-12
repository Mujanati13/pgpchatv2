import 'package:flutter/services.dart';

/// Listens for screenshot attempts via native MethodChannel.
///
/// - **Android**: FLAG_SECURE blocks screenshots (black screen).
///   The channel only reports that prevention is active.
/// - **iOS**: The native side detects `userDidTakeScreenshotNotification`
///   and invokes "onScreenshotDetected" on this channel.
class ScreenshotService {
  static const _channel = MethodChannel('com.pgpchat/screenshot');

  Function()? _onScreenshotDetected;

  /// Start listening. [onDetected] fires when iOS detects a screenshot.
  void startListening({required Function() onDetected}) {
    _onScreenshotDetected = onDetected;
    _channel.setMethodCallHandler(_handleMethod);
  }

  /// Stop listening.
  void stopListening() {
    _onScreenshotDetected = null;
    _channel.setMethodCallHandler(null);
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    if (call.method == 'onScreenshotDetected') {
      _onScreenshotDetected?.call();
    }
  }
}
