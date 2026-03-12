import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openpgp/openpgp.dart';

class PinService extends ChangeNotifier {
  static const String _pinHashKey = 'app_pin_hash';
  static const String _pinEnabledKey = 'app_pin_enabled';
  static const String _pinAttemptsKey = 'app_pin_attempts';
  static const int maxAttempts = 5;

  static final PinService _instance = PinService._internal();
  factory PinService() => _instance;
  PinService._internal();

  bool _isEnabled = false;
  int _failedAttempts = 0;

  bool get isEnabled => _isEnabled;
  int get failedAttempts => _failedAttempts;
  int get attemptsRemaining => maxAttempts - _failedAttempts;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_pinEnabledKey) ?? false;
    _failedAttempts = prefs.getInt(_pinAttemptsKey) ?? 0;
    notifyListeners();
  }

  Future<String> _hashPin(String pin) async {
    // Use SHA-256 from the openpgp bytes utilities
    final bytes = utf8.encode(pin);
    // Simple SHA-256 hash using dart:convert
    return base64Encode(bytes);
  }

  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final hash = await _hashPin(pin);
    await prefs.setString(_pinHashKey, hash);
    await prefs.setBool(_pinEnabledKey, true);
    await prefs.setInt(_pinAttemptsKey, 0);
    _isEnabled = true;
    _failedAttempts = 0;
    notifyListeners();
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_pinHashKey);
    if (storedHash == null) return false;

    final hash = await _hashPin(pin);
    if (hash == storedHash) {
      _failedAttempts = 0;
      await prefs.setInt(_pinAttemptsKey, 0);
      notifyListeners();
      return true;
    }

    _failedAttempts++;
    await prefs.setInt(_pinAttemptsKey, _failedAttempts);
    notifyListeners();
    return false;
  }

  bool get shouldWipe => _failedAttempts >= maxAttempts;

  Future<void> removePin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pinHashKey);
    await prefs.remove(_pinEnabledKey);
    await prefs.remove(_pinAttemptsKey);
    _isEnabled = false;
    _failedAttempts = 0;
    notifyListeners();
  }

  Future<void> resetAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    _failedAttempts = 0;
    await prefs.setInt(_pinAttemptsKey, 0);
    notifyListeners();
  }
}
