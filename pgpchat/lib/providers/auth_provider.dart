import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart' show navigatorKey;
import '../screens/login_screen.dart';
import '../services/api_service.dart';
import '../services/pgp_service.dart';
import '../services/push_notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api = ApiService();
  final PgpService _pgp = PgpService();
  final PushNotificationService _push = PushNotificationService();

  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _username;
  String? _userId;
  String? _error;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get username => _username;
  String? get userId => _userId;
  String? get error => _error;

  // Clears local state and pops all navigation routes to show login screen.
  void _clearAuthAndNavigate() {
    _isAuthenticated = false;
    _username = null;
    _userId = null;
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('username');
      prefs.remove('user_id');
    });
    notifyListeners();
    // Pop all pushed routes so login screen becomes visible immediately.
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> checkAuth() async {
    // Register global 401 handler — fires whenever any API call is unauthorized
    ApiService.onUnauthorized = () {
      if (_isAuthenticated) _clearAuthAndNavigate();
    };

    final token = await _api.token;
    if (token != null) {
      _isAuthenticated = true;
      final prefs = await SharedPreferences.getInstance();
      _username = prefs.getString('username');
      _userId = prefs.getString('user_id');
      try {
        await _push.syncTokenWithServer();
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<bool> register(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _api.register(username, password);
      _isAuthenticated = true;
      _username = username;
      _userId = result['userId']?.toString();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', username);
      if (_userId != null) await prefs.setString('user_id', _userId!);
      try {
        await _push.syncTokenWithServer();
      } catch (_) {}
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Connection error. Please check server settings.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await _api.login(username, password);
      _isAuthenticated = true;
      _username = username;
      _userId = result['userId']?.toString();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', username);
      if (_userId != null) await prefs.setString('user_id', _userId!);
      try {
        await _push.syncTokenWithServer();
      } catch (_) {}
      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Connection error. Please check server settings.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _push.unregisterTokenFromServer();
    } catch (_) {}
    try {
      await _api.logout();
    } catch (_) {}
    _clearAuthAndNavigate();
  }

  Future<bool> resetPgp() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _api.resetPgp();
      await _pgp.wipeKeys();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Failed to reset PGP';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
