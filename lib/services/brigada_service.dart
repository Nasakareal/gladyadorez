import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../models/brigada.dart';
import 'api_client.dart';

class BrigadaService {
  const BrigadaService(this.api);
  final ApiClient api;

  Future<BrigadaPage> fetch({
    String? search,
    String? section,
    int? district,
    int page = 1,
  }) async {
    final response = await api.dio.get(
      '/v1/brigadas',
      queryParameters: {
        'page': page,
        if (search != null && search.trim().isNotEmpty) 'q': search.trim(),
        if (section != null && section.trim().isNotEmpty)
          'seccion': section.trim(),
        if (district != null) 'distrito': district,
      },
    );
    final json = Map<String, dynamic>.from(response.data as Map);
    final data = json['data'] as List? ?? const [];
    return BrigadaPage(
      items: data
          .whereType<Map>()
          .map((item) => Brigada.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      currentPage: _int(json['current_page'], page),
      lastPage: _int(json['last_page'], 1),
      total: _int(json['total'], data.length),
    );
  }

  Future<Brigada> find(int id) async {
    final response = await api.dio.get('/v1/brigadas/$id');
    return Brigada.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<List<BrigadaSection>> sections() async {
    final response = await api.dio.get('/v1/brigadas/secciones');
    final data = response.data as List? ?? const [];
    return data
        .whereType<Map>()
        .map((item) => BrigadaSection.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<BrigadaParticipation> attend(
    int id,
    XFile photo, {
    String? notes,
  }) async {
    final data = FormData.fromMap({
      'foto': await MultipartFile.fromFile(
        photo.path,
        filename: photo.name.isEmpty ? 'asistencia.jpg' : photo.name,
      ),
      if (notes != null && notes.trim().isNotEmpty)
        'observaciones': notes.trim(),
    });
    final response = await api.dio.post(
      '/v1/brigadas/$id/participar',
      data: data,
    );
    return BrigadaParticipation.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<Brigada> save({
    int? id,
    required int sectionId,
    required String responsible,
    String? phone,
    String? address,
    String? notes,
    required double latitude,
    required double longitude,
    required bool active,
  }) async {
    final data = {
      'seccion_id': sectionId,
      'responsable': responsible.trim(),
      'telefono': phone?.trim(),
      'direccion': address?.trim(),
      'observaciones': notes?.trim(),
      'lat': latitude,
      'lng': longitude,
      'activo': active,
      'ubicacion_google': 'https://www.google.com/maps?q=$latitude,$longitude',
    };
    final response = id == null
        ? await api.dio.post('/v1/brigadas', data: data)
        : await api.dio.put('/v1/brigadas/$id', data: data);
    return Brigada.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<void> delete(int id) => api.dio.delete('/v1/brigadas/$id');

  static String message(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final errors = data['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) return '${first.first}';
        }
        if (data['message'] != null) return '${data['message']}';
      }
      if (error.response?.statusCode == 403) {
        return 'No tienes permiso para realizar esta acción.';
      }
    }
    return 'No se pudo completar la operación. Intenta nuevamente.';
  }

  static int _int(Object? value, int fallback) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
}
