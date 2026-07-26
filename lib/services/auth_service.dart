import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient api;
  AuthService(this.api);

  static const _key = 'token';
  static const _storage = FlutterSecureStorage();
  String landingRoute = '/home';

  Future<bool> login(String email, String password) async {
    final res = await api.dio.post(
      '/v1/auth/login',
      data: {'email': email, 'password': password},
    );
    final token = res.data['token'] as String?;
    if (token != null && token.isNotEmpty) {
      await _storage.write(key: _key, value: token);
      final user = res.data['user'];
      final roles = user is Map && user['roles'] is List
          ? List<String>.from(
              (user['roles'] as List).map((role) => role.toString()),
            )
          : const <String>[];
      landingRoute = roles.contains('Lonas') ? '/lonas' : '/home';
      return true;
    }
    return false;
  }

  Future<void> logout() async {
    final t = await token();
    if (t != null) {
      try {
        await api.dio.post(
          '/v1/auth/logout',
          options: Options(headers: {'Authorization': 'Bearer $t'}),
        );
      } catch (_) {}
    }
    await _storage.delete(key: _key);
  }

  Future<String?> token() => _storage.read(key: _key);
}
