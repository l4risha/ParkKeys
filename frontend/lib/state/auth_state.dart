import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/api_client.dart';

const _tokenKey = 'parkkeys_token';

/// Naghold sa logged-in user + token. Provider mag-notify sa router/UI.
class AuthState extends ChangeNotifier {
  AuthState(this.api);

  final ApiClient api;

  User? _user;
  bool _restoring = true;

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isRestoring => _restoring;

  String get role => _user?.role ?? '';

  /// Role-based home. Gigamit sa router guard.
  String get homePath => switch (role) {
    'admin' => '/admin',
    'driver' => '/driver',
    _ => '/passenger',
  };

  /// Basaha ang saved token sa browser (localStorage) inig reload.
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token != null && token.isNotEmpty) {
      api.setToken(token);
      try {
        _user = await api.me();
      } catch (_) {
        await prefs.remove(_tokenKey);
        api.setToken(null);
      }
    }
    _restoring = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final result = await api.login(email, password);
    await _save(result);
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final result = await api.register(
      email: email,
      password: password,
      fullName: fullName,
    );
    await _save(result);
  }

  Future<void> _save(AuthResult result) async {
    api.setToken(result.token);
    _user = result.user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, result.token);
    notifyListeners();
  }

  Future<void> logout() async {
    api.setToken(null);
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    notifyListeners();
  }
}
