import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// ==========================
///  Modelo: Comunicado
/// ==========================
class Comunicado {
  final int id;
  final String titulo;
  final String contenido;
  final DateTime? visibleDesde;
  final DateTime? visibleHasta;

  Comunicado({
    required this.id,
    required this.titulo,
    required this.contenido,
    this.visibleDesde,
    this.visibleHasta,
  });

  factory Comunicado.fromJson(Map<String, dynamic> j) => Comunicado(
    id: j['id'] as int,
    titulo: (j['titulo'] ?? '') as String,
    contenido: (j['contenido'] ?? '') as String,
    visibleDesde: j['visible_desde'] != null
        ? DateTime.parse(j['visible_desde'])
        : null,
    visibleHasta: j['visible_hasta'] != null
        ? DateTime.parse(j['visible_hasta'])
        : null,
  );
}

/// ==========================
///  Cliente API base
/// ==========================
class ApiClient {
  final Dio dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiClient()
    : dio = Dio(
        BaseOptions(
          baseUrl: (dotenv.env['API_BASE_URL'] ?? 'https://gladyadorez.com/api')
              .trim(),
          headers: {'Accept': 'application/json'},
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 20),
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Leer token actual; migrar desde 'auth_token' si existe (legacy).
          var token = await _storage.read(key: 'token');
          if (token == null || token.isEmpty) {
            final legacy = await _storage.read(key: 'auth_token');
            if (legacy != null && legacy.isNotEmpty) {
              await _storage.write(key: 'token', value: legacy);
              await _storage.delete(key: 'auth_token');
              token = legacy;
            }
          }
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  Future<Response<dynamic>> get(String path, {Map<String, dynamic>? query}) {
    return dio.get(path, queryParameters: query);
  }

  Future<Response<dynamic>> post(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
  }) {
    return dio.post(path, data: data, queryParameters: query);
  }

  Future<void> setToken(String token) async {
    await _storage.write(key: 'token', value: token);
    await _storage.delete(key: 'auth_token'); // limpia legacy
  }

  Future<void> clearToken() async {
    await _storage.delete(key: 'token');
    await _storage.delete(key: 'auth_token');
  }

  Future<Map<String, String>> authorizationHeaders() async {
    final token =
        await _storage.read(key: 'token') ??
        await _storage.read(key: 'auth_token');
    return {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }
}

/// =======================================
///  Endpoints de Comunicados sobre ApiClient
/// =======================================
extension ComunicadoApi on ApiClient {
  /// GET /v1/comunicados  (paginado)
  /// Retorna tupla con page, limit, total e items.
  Future<({int page, int limit, int total, List<Comunicado> items})>
  fetchComunicados({String? municipio, int page = 1, int limit = 20}) async {
    final q = <String, dynamic>{
      'page': page.toString(),
      'limit': limit.toString(),
      if (municipio != null && municipio.isNotEmpty) 'municipio': municipio,
    };

    final res = await dio.get('/v1/comunicados', queryParameters: q);
    final data = res.data as Map<String, dynamic>;

    final items = ((data['items'] as List?) ?? [])
        .map((e) => Comunicado.fromJson(e as Map<String, dynamic>))
        .toList();

    return (
      page: (data['page'] ?? page) as int,
      limit: (data['limit'] ?? limit) as int,
      total: (data['total'] ?? items.length) as int,
      items: items,
    );
  }

  /// GET /v1/comunicados/{id}
  Future<Comunicado> fetchComunicado(int id, {String? municipio}) async {
    final res = await dio.get(
      '/v1/comunicados/$id',
      queryParameters: {
        if (municipio != null && municipio.isNotEmpty) 'municipio': municipio,
      },
    );
    return Comunicado.fromJson(res.data as Map<String, dynamic>);
  }
}
