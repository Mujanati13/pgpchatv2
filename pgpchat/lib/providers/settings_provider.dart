import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class SettingsProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  bool _autoDeleteEnabled = true;
  int _autoDeleteHours = 24;
  bool _contactsEnabled = false;
  bool _isLoading = false;

  bool get autoDeleteEnabled => _autoDeleteEnabled;
  int get autoDeleteHours => _autoDeleteHours;
  bool get contactsEnabled => _contactsEnabled;
  bool get isLoading => _isLoading;

  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _api.getSettings();
      final settings = result['settings'] as Map<String, dynamic>?;
      if (settings != null) {
        _autoDeleteEnabled = settings['auto_delete_enabled'] == 1 ||
            settings['auto_delete_enabled'] == true;
        _autoDeleteHours = settings['auto_delete_hours'] as int? ?? 24;
        _contactsEnabled = settings['contacts_enabled'] == 1 ||
            settings['contacts_enabled'] == true;
      }
    } catch (_) {}

    _isLoading = false;
    notifyListeners();
  }

  Future<void> setAutoDelete(bool enabled) async {
    _autoDeleteEnabled = enabled;
    notifyListeners();
    await _api.updateSettings({'autoDeleteEnabled': enabled});
  }

  Future<void> setAutoDeleteHours(int hours) async {
    _autoDeleteHours = hours;
    notifyListeners();
    await _api.updateSettings({'autoDeleteHours': hours});
  }

  Future<void> setContactsEnabled(bool enabled) async {
    _contactsEnabled = enabled;
    notifyListeners();
    await _api.updateSettings({'contactsEnabled': enabled});
  }

  Future<void> autoDeleteNow() async {
    await _api.autoDeleteNow(hours: _autoDeleteHours);
  }
}
