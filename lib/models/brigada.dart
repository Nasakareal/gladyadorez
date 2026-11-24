class BrigadaSection {
  const BrigadaSection({
    required this.id,
    required this.number,
    required this.localDistrict,
    required this.municipality,
  });

  final int id;
  final String number;
  final int localDistrict;
  final String municipality;

  factory BrigadaSection.fromJson(Map<String, dynamic> json) => BrigadaSection(
    id: _int(json['id']),
    number: '${json['numero'] ?? json['seccion'] ?? ''}',
    localDistrict: _int(json['distrito_local']),
    municipality: '${json['municipio'] ?? 'Morelia'}',
  );

  String get label => 'DL $localDistrict · Sección $number';
}

class BrigadaParticipation {
  const BrigadaParticipation({
    required this.id,
    required this.evidenceUrl,
    this.userName,
    this.attendedAt,
    this.notes,
  });

  final int id;
  final String evidenceUrl;
  final String? userName;
  final DateTime? attendedAt;
  final String? notes;

  factory BrigadaParticipation.fromJson(Map<String, dynamic> json) {
    final user = json['usuario'];
    return BrigadaParticipation(
      id: _int(json['id']),
      evidenceUrl: '${json['evidencia_url'] ?? ''}',
      userName: user is Map ? user['name']?.toString() : null,
      attendedAt: DateTime.tryParse('${json['asistio_en'] ?? ''}'),
      notes: json['observaciones']?.toString(),
    );
  }
}

class Brigada {
  const Brigada({
    required this.id,
    required this.section,
    required this.responsible,
    required this.latitude,
    required this.longitude,
    required this.active,
    required this.attendanceCount,
    required this.didAttend,
    this.phone,
    this.address,
    this.googleMapsUrl,
    this.notes,
    this.myParticipation,
    this.participants = const [],
  });

  final int id;
  final BrigadaSection section;
  final String responsible;
  final String? phone;
  final String? address;
  final String? googleMapsUrl;
  final double latitude;
  final double longitude;
  final bool active;
  final String? notes;
  final int attendanceCount;
  final bool didAttend;
  final BrigadaParticipation? myParticipation;
  final List<BrigadaParticipation> participants;

  factory Brigada.fromJson(Map<String, dynamic> json) {
    final section = json['seccion'] is Map
        ? Map<String, dynamic>.from(json['seccion'] as Map)
        : <String, dynamic>{};
    final mine = json['mi_participacion'];
    final rawParticipants = json['participantes'] as List? ?? const [];
    return Brigada(
      id: _int(json['id']),
      section: BrigadaSection.fromJson(section),
      responsible: '${json['responsable'] ?? ''}',
      phone: json['telefono']?.toString(),
      address: json['direccion']?.toString(),
      googleMapsUrl: json['ubicacion_google']?.toString(),
      latitude: _double(json['lat']),
      longitude: _double(json['lng']),
      active: _bool(json['activo']),
      notes: json['observaciones']?.toString(),
      attendanceCount: _int(json['participantes_count']),
      didAttend: _bool(json['ya_participe']),
      myParticipation: mine is Map
          ? BrigadaParticipation.fromJson(Map<String, dynamic>.from(mine))
          : null,
      participants: rawParticipants
          .whereType<Map>()
          .map(
            (item) =>
                BrigadaParticipation.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList(),
    );
  }
}

class BrigadaPage {
  const BrigadaPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });
  final List<Brigada> items;
  final int currentPage;
  final int lastPage;
  final int total;
}

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
double _double(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? 0;
bool _bool(Object? value) => value == true || value == 1 || '$value' == '1';
