import 'package:dio/dio.dart';

import 'api_client.dart';

class AvanceService {
  AvanceService(this.api);

  final ApiClient api;

  Future<AvanceSnapshot> fetch([
    Map<String, dynamic> filters = const {},
  ]) async {
    final query = Map<String, dynamic>.from(filters)
      ..removeWhere((_, value) => value == null || '$value'.trim().isEmpty);
    final response = await api.dio.get('/v1/avance', queryParameters: query);
    return AvanceSnapshot.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> saveGoal({
    required String municipalityCode,
    required int localDistrict,
    required int convinced,
    int? banners,
  }) async {
    await api.dio.post(
      '/v1/avance/metas',
      data: {
        'cve_mun': municipalityCode,
        'distrito_local': localDistrict,
        'meta_convencidos': convinced,
        'meta_lonas': banners,
      },
    );
  }

  Future<Map<String, dynamic>> fetchPeople(
    Map<String, dynamic> filters, {
    int page = 1,
  }) async {
    final query = Map<String, dynamic>.from(filters)
      ..['page'] = page
      ..removeWhere((_, value) => value == null || '$value'.trim().isEmpty);
    final response = await api.dio.get(
      '/v1/avance/convencidos',
      queryParameters: query,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  static String message(Object error) {
    if (error is DioException) {
      if (error.response?.statusCode == 403) {
        return 'No tienes permiso para realizar esta acción.';
      }
      final data = error.response?.data;
      if (data is Map && data['message'] != null) return '${data['message']}';
    }
    return 'No se pudo cargar el avance. Intenta nuevamente.';
  }
}

class AvanceSnapshot {
  const AvanceSnapshot({
    required this.rows,
    required this.totals,
    required this.localDistricts,
    required this.federalDistricts,
    required this.referents,
    required this.capturers,
    required this.topCapturers,
    required this.topReferents,
    required this.sectionsByScope,
  });

  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic> totals;
  final List<String> localDistricts;
  final List<String> federalDistricts;
  final List<String> referents;
  final List<Map<String, dynamic>> capturers;
  final List<Map<String, dynamic>> topCapturers;
  final List<Map<String, dynamic>> topReferents;
  final Map<String, List<Map<String, dynamic>>> sectionsByScope;

  factory AvanceSnapshot.fromJson(Map<String, dynamic> json) => AvanceSnapshot(
    rows: _maps(json['avance']),
    totals: json['totales'] is Map
        ? Map<String, dynamic>.from(json['totales'] as Map)
        : const {},
    localDistricts: _strings(json['distritosLocales']),
    federalDistricts: _strings(json['distritosFederales']),
    referents: _strings(json['referentes']),
    capturers: _maps(json['capturistas']),
    topCapturers: _maps(json['topCapturistas']),
    topReferents: _maps(json['topReferentes']),
    sectionsByScope: _sectionMap(json['seccionesPorMunicipio']),
  );

  static List<Map<String, dynamic>> _maps(dynamic value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
      : const [];

  static List<String> _strings(dynamic value) =>
      value is List ? value.map((item) => '$item').toList() : const [];

  static Map<String, List<Map<String, dynamic>>> _sectionMap(dynamic value) {
    if (value is! Map) return const {};
    return value.map((key, items) => MapEntry('$key', _maps(items)));
  }
}
