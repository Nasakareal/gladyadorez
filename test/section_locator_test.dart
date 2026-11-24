import 'package:flutter_test/flutter_test.dart';
import 'package:sistema_afiliados_app/services/section_locator.dart';

void main() {
  const sections = [
    ElectoralSectionPoint(
      section: '1001',
      latitude: 19.7000,
      longitude: -101.2000,
    ),
    ElectoralSectionPoint(
      section: '1002',
      latitude: 19.8000,
      longitude: -101.1000,
    ),
  ];

  test('returns the section whose centroid is nearest', () {
    final match = findNearestSection(
      sections,
      latitude: 19.7050,
      longitude: -101.2020,
    );

    expect(match?.point.section, '1001');
    expect(match!.distanceKm, lessThan(1));
  });

  test('does not suggest a section for a distant coordinate', () {
    final match = findNearestSection(
      sections,
      latitude: 25.6866,
      longitude: -100.3161,
    );

    expect(match, isNull);
  });

  test('parses numeric coordinates returned as strings', () {
    final point = ElectoralSectionPoint.fromJson({
      'seccion': 4321,
      'centroid_lat': '19.7001',
      'centroid_lng': '-101.2002',
    });

    expect(point.section, '4321');
    expect(point.latitude, 19.7001);
    expect(point.longitude, -101.2002);
  });
}
