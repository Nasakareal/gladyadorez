import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_afiliados_app/models/lona.dart';

void main() {
  test('Lona parses numeric strings and nested capturista', () {
    final lona = Lona.fromJson({
      'id': 7,
      'seccion': '1234',
      'direccion': 'Av. Madero 100',
      'responsable': 'Responsable',
      'lat': '19.7026000',
      'lng': '-101.1922000',
      'foto_url': 'https://example.test/api/v1/lonas/7/foto',
      'capturista': {'id': 3, 'name': 'Captura Lonas 01'},
      'created_at': '2026-07-26T12:30:00Z',
    });

    expect(lona.id, 7);
    expect(lona.lat, 19.7026);
    expect(lona.lng, -101.1922);
    expect(lona.capturista, 'Captura Lonas 01');
    expect(lona.createdAt, DateTime.utc(2026, 7, 26, 12, 30));
  });
}
