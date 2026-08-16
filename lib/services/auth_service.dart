import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

class SessionUser {
  const SessionUser({
    required this.id,
    required this.name,
    required this.email,
    required this.roles,
    required this.permissions,
  });

  final int id;
  final String name;
  final String email;
  final Set<String> roles;
  final Set<String> permissions;

  bool get isSuperAdmin => roles.contains('SuperAdmin');

  factory SessionUser.fromJson(Map<String, dynamic> json) => SessionUser(
    id: int.tryParse('${json['id'] ?? 0}') ?? 0,
    name: '${json['name'] ?? ''}',
    email: '${json['email'] ?? ''}',
    roles: ((json['roles'] as List?) ?? const [])
        .map((item) => '$item')
        .toSet(),
    permissions: ((json['permissions'] as List?) ?? const [])
        .map((item) => '$item')
        .toSet(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'roles': roles.toList(),
    'permissions': permissions.toList(),
  };
}

class AuthService extends ChangeNotifier {
  AuthService(this.api);

  final ApiClient api;
  static const _tokenKey = 'token';
  static const _userKey = 'session_user';
  static const _storage = FlutterSecureStorage();

  SessionUser? _user;
  SessionUser? get user => _user;
  bool get isAuthenticated => _user != null;

  bool can(String permission) =>
      _user?.isSuperAdmin == true ||
      (_user?.permissions.contains(permission) ?? false);

  bool canAny(Iterable<String> permissions) => permissions.any(can);

  Future<bool> restoreSession() async {
    String? storedToken;
    try {
      storedToken = await token();
    } catch (error) {
      debugPrint('No se pudo leer el token seguro: $error');
      return false;
    }
    if (storedToken == null || storedToken.isEmpty) return false;

    final preferences = await SharedPreferences.getInstance();
    String? cached = preferences.getString(_userKey);
    // Migración de versiones que guardaban también el perfil en el almacén
    // seguro. El token continúa siempre dentro de FlutterSecureStorage.
    if (cached == null || cached.isEmpty) {
      try {
        cached = await _storage.read(key: _userKey);
      } catch (error) {
        debugPrint('No se pudo migrar la sesión anterior: $error');
      }
    }
    if (cached != null) {
      try {
        _user = SessionUser.fromJson(
          Map<String, dynamic>.from(jsonDecode(cached) as Map),
        );
        notifyListeners();
      } catch (_) {
        await preferences.remove(_userKey);
      }
    }

    // Una sesión ya confirmada localmente abre la app de inmediato. La
    // validación remota ocurre en segundo plano para que una caída de red o
    // una ruta /me temporalmente desactualizada no parezca un cierre de sesión.
    if (_user != null) {
      unawaited(
        _refreshSession(clearOnUnauthorized: false, storedToken: storedToken),
      );
      return true;
    }

    return _refreshSession(clearOnUnauthorized: true, storedToken: storedToken);
  }

  Future<bool> _refreshSession({
    required bool clearOnUnauthorized,
    required String storedToken,
  }) async {
    try {
      final response = await api.dio.get(
        '/v1/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $storedToken'}),
      );
      final refreshed = SessionUser.fromJson(
        Map<String, dynamic>.from(response.data as Map),
      );
      // Mantiene permisos de la caché al hablar temporalmente con una versión
      // anterior de la API que aún no los incluya en /auth/me.
      _user = refreshed.permissions.isEmpty && _user?.id == refreshed.id
          ? SessionUser(
              id: refreshed.id,
              name: refreshed.name,
              email: refreshed.email,
              roles: refreshed.roles.isEmpty ? _user!.roles : refreshed.roles,
              permissions: _user!.permissions,
            )
          : refreshed;
      await _persistUser();
      notifyListeners();
      return true;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 && clearOnUnauthorized) {
        await _clearLocalSession();
      }
      return _user != null;
    } catch (error) {
      debugPrint('No se pudo actualizar la sesión: $error');
      return _user != null;
    }
  }

  Future<bool> login(String email, String password) async {
    final response = await api.dio.post(
      '/v1/auth/login',
      data: {'email': email, 'password': password},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final authToken = data['token'] as String?;
    final rawUser = data['user'];
    if (authToken == null || authToken.isEmpty || rawUser is! Map) return false;

    await _storage.write(key: _tokenKey, value: authToken);
    _user = SessionUser.fromJson(Map<String, dynamic>.from(rawUser));
    await _persistUser();
    notifyListeners();
    return true;
  }

  String get landingRoute {
    if (canAny([
      'afiliados.ver',
      'actividades.ver',
      'mapa.ver',
      'reportes.ver',
      'lonas.ver',
      'comunicados.ver',
    ])) {
      return '/home';
    }
    return '/home';
  }

  Future<void> logout() async {
    if (await token() != null) {
      try {
        await api.dio.post('/v1/auth/logout');
      } catch (_) {}
    }
    await _clearLocalSession();
  }

  Future<void> _persistUser() async {
    final current = _user;
    if (current != null) {
      final encoded = jsonEncode(current.toJson());
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_userKey, encoded);
      // Conserva una copia para migrar instalaciones anteriores sin perder
      // sesión; si el dispositivo no admite esta escritura, la caché común es
      // suficiente porque no contiene el token.
      try {
        await _storage.write(key: _userKey, value: encoded);
      } catch (error) {
        debugPrint(
          'No se pudo duplicar el perfil en almacenamiento seguro: $error',
        );
      }
    }
  }

  Future<void> _clearLocalSession() async {
    _user = null;
    for (final key in [_tokenKey, 'auth_token', _userKey]) {
      try {
        await _storage.delete(key: key);
      } catch (error) {
        debugPrint('No se pudo limpiar $key: $error');
      }
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_userKey);
    notifyListeners();
  }

  Future<String?> token() => _storage.read(key: _tokenKey);
}
