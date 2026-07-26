import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../models/lona.dart';
import 'api_client.dart';

class LonaService {
  const LonaService(this.api);

  final ApiClient api;

  Future<LonaPage> fetchLonas({
    String? search,
    String? seccion,
    int page = 1,
  }) async {
    final response = await api.dio.get(
      '/v1/lonas',
      queryParameters: {
        'page': page,
        if (search != null && search.trim().isNotEmpty) 'q': search.trim(),
        if (seccion != null && seccion.trim().isNotEmpty)
          'seccion': seccion.trim(),
      },
    );
    final json = Map<String, dynamic>.from(response.data as Map);
    final rawItems = (json['data'] as List?) ?? const [];
    return LonaPage(
      items: rawItems
          .map((item) => Lona.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      currentPage: _asInt(json['current_page'], page),
      lastPage: _asInt(json['last_page'], 1),
      total: _asInt(json['total'], rawItems.length),
    );
  }

  Future<List<Lona>> fetchMapData() async {
    final response = await api.dio.get('/v1/lonas/mapa');
    final raw = response.data as List? ?? const [];
    return raw
        .map((item) => Lona.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<Lona> fetchLona(int id) async {
    final response = await api.dio.get('/v1/lonas/$id');
    return Lona.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<Lona> createLona({
    required String seccion,
    required String direccion,
    required String responsable,
    required double lat,
    required double lng,
    required XFile foto,
  }) async {
    final data = FormData.fromMap({
      'seccion': seccion.trim(),
      'direccion': direccion.trim(),
      'responsable': responsable.trim(),
      'lat': lat.toStringAsFixed(7),
      'lng': lng.toStringAsFixed(7),
      'ubicacion_google':
          'https://www.google.com/maps?q=${lat.toStringAsFixed(7)},${lng.toStringAsFixed(7)}',
      'foto': await MultipartFile.fromFile(
        foto.path,
        filename: foto.name.isEmpty ? 'lona.jpg' : foto.name,
      ),
    });
    final response = await api.dio.post('/v1/lonas', data: data);
    return Lona.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  static int _asInt(Object? value, int fallback) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
}
