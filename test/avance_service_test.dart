import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_afiliados_app/services/avance_service.dart';

void main() {
  test('parses progress data returned by the Laravel API', () {
    final snapshot = AvanceSnapshot.fromJson({
      'avance': [
        {
          'cve_mun': '001',
          'municipio': 'Acuitzio',
          'distrito_local': 15,
          'total_convencidos': 20,
          'meta_convencidos': 180,
        },
      ],
      'totales': {'total_convencidos': 20},
      'distritosLocales': [15],
      'distritosFederales': [8],
      'referentes': ['Gladyz Butanda'],
      'capturistas': [
        {'id': 7, 'name': 'Capturista'},
      ],
      'topCapturistas': [],
      'topReferentes': [],
      'seccionesPorMunicipio': {
        '001|15': [
          {'seccion': '0001', 'total': 20},
        ],
      },
    });

    expect(snapshot.rows.single['municipio'], 'Acuitzio');
    expect(snapshot.localDistricts, ['15']);
    expect(snapshot.sectionsByScope['001|15']?.single['total'], 20);
  });
}
