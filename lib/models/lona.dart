class Lona {
  const Lona({
    required this.id,
    required this.seccion,
    required this.direccion,
    required this.responsable,
    required this.lat,
    required this.lng,
    required this.fotoUrl,
    this.ubicacionGoogle,
    this.capturista,
    this.createdAt,
  });

  final int id;
  final String seccion;
  final String direccion;
  final String responsable;
  final double lat;
  final double lng;
  final String fotoUrl;
  final String? ubicacionGoogle;
  final String? capturista;
  final DateTime? createdAt;

  factory Lona.fromJson(Map<String, dynamic> json) {
    final capturista = json['capturista'];
    return Lona(
      id: _asInt(json['id']),
      seccion: '${json['seccion'] ?? ''}',
      direccion: '${json['direccion'] ?? ''}',
      responsable: '${json['responsable'] ?? ''}',
      lat: _asDouble(json['lat']),
      lng: _asDouble(json['lng']),
      fotoUrl: '${json['foto_url'] ?? ''}',
      ubicacionGoogle: json['ubicacion_google']?.toString(),
      capturista: capturista is Map
          ? capturista['name']?.toString()
          : capturista?.toString(),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}'),
    );
  }

  static int _asInt(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  static double _asDouble(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
}

class LonaPage {
  const LonaPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<Lona> items;
  final int currentPage;
  final int lastPage;
  final int total;
}
