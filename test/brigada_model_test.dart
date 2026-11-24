import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_afiliados_app/models/brigada.dart';

void main() {
  test('parses a brigade with attendance state', () {
    final brigade = Brigada.fromJson({
      'id': 9,
      'seccion': {
        'id': 3,
        'numero': '1234',
        'distrito_local': 10,
        'municipio': 'Morelia',
      },
      'responsable': 'Responsable',
      'lat': '19.7000000',
      'lng': '-101.1900000',
      'activo': true,
      'participantes_count': 2,
      'ya_participe': true,
      'mi_participacion': {
        'id': 8,
        'asistio_en': '2026-11-23T10:00:00-06:00',
        'evidencia_url': 'https://example.test/photo',
      },
    });

    expect(brigade.section.label, 'DL 10 · Sección 1234');
    expect(brigade.attendanceCount, 2);
    expect(brigade.didAttend, isTrue);
    expect(brigade.myParticipation?.id, 8);
  });
}
