import 'dart:math' as math;

class ElectoralSectionPoint {
  const ElectoralSectionPoint({
    required this.section,
    required this.latitude,
    required this.longitude,
  });

  final String section;
  final double latitude;
  final double longitude;

  factory ElectoralSectionPoint.fromJson(Map<String, dynamic> json) {
    return ElectoralSectionPoint(
      section: '${json['seccion'] ?? ''}'.trim(),
      latitude: _asDouble(json['centroid_lat'])!,
      longitude: _asDouble(json['centroid_lng'])!,
    );
  }

  static bool hasCoordinates(Map<String, dynamic> json) =>
      '${json['seccion'] ?? ''}'.trim().isNotEmpty &&
      _asDouble(json['centroid_lat']) != null &&
      _asDouble(json['centroid_lng']) != null;

  static double? _asDouble(Object? value) =>
      value is num ? value.toDouble() : double.tryParse('$value');
}

class SectionMatch {
  const SectionMatch({required this.point, required this.distanceKm});

  final ElectoralSectionPoint point;
  final double distanceKm;
}

SectionMatch? findNearestSection(
  Iterable<ElectoralSectionPoint> sections, {
  required double latitude,
  required double longitude,
  double maxDistanceKm = 50,
}) {
  ElectoralSectionPoint? nearest;
  var nearestDistance = double.infinity;

  for (final section in sections) {
    final distance = _distanceKm(
      latitude,
      longitude,
      section.latitude,
      section.longitude,
    );
    if (distance < nearestDistance) {
      nearest = section;
      nearestDistance = distance;
    }
  }

  if (nearest == null || nearestDistance > maxDistanceKm) return null;
  return SectionMatch(point: nearest, distanceKm: nearestDistance);
}

double _distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0088;
  final latDelta = _radians(lat2 - lat1);
  final lngDelta = _radians(lng2 - lng1);
  final a =
      math.sin(latDelta / 2) * math.sin(latDelta / 2) +
      math.cos(_radians(lat1)) *
          math.cos(_radians(lat2)) *
          math.sin(lngDelta / 2) *
          math.sin(lngDelta / 2);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _radians(double degrees) => degrees * math.pi / 180;
