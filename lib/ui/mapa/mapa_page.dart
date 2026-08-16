import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_client.dart';
import '../../widgets/safe_osm_tile_layer.dart';

class MapaPage extends StatefulWidget {
  const MapaPage({super.key});

  @override
  State<MapaPage> createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
  static const _countsCacheKey = 'map_counts_cache_v2';
  static const _pointsCacheKey = 'map_points_cache_v2';
  static const _markerZoom = 8.5;
  static const _scale = <Color>[
    Color(0xffe9ecef),
    Color(0xffcce5d0),
    Color(0xff99cfaa),
    Color(0xff66b985),
    Color(0xff2ea15e),
    Color(0xff0b8043),
  ];

  final _map = MapController();
  late final TileLayer _tileLayer;
  final List<_MunGeom> _municipios = [];
  final List<Polygon> _polygons = [];
  final List<CircleMarker> _circles = [];
  Map<String, int> _conteo = {};
  Timer? _moveDebounce;
  bool _loading = true;
  bool _loadingPoints = false;
  bool _offlineData = false;
  int _min = 0;
  int _max = 0;
  double _zoom = 7;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tileLayer = buildSafeOpenStreetMapTileLayer(
      userAgentPackageName: 'mx.utmorelia.sistema_afiliados_app',
    );
    _initialize();
  }

  @override
  void dispose() {
    _moveDebounce?.cancel();
    _map.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _restoreCounts(prefs.getString(_countsCacheKey));
      _restorePoints(prefs.getString(_pointsCacheKey));

      final source = await rootBundle.loadString(
        'assets/geo/michoacan_simplified.json',
      );
      final parsed = await compute(_parseMunicipios, source);
      _municipios
        ..clear()
        ..addAll(parsed.map(_MunGeom.fromTransfer));
      _rebuildPolygons();
      if (mounted) setState(() => _loading = false);

      await _refreshCounts();
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadVisiblePoints());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _message(error);
      });
    }
  }

  Future<void> _refreshCounts() async {
    try {
      final response = await context.read<ApiClient>().dio.get('/v1/mapa');
      final raw = response.data is String
          ? jsonDecode(response.data)
          : response.data;
      final values = (raw['conteo'] as Map?)?.cast<String, dynamic>() ?? {};
      _conteo = values.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      );
      _computeRange();
      _rebuildPolygons();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_countsCacheKey, jsonEncode(_conteo));
      if (mounted) setState(() => _offlineData = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _offlineData = true;
        if (_conteo.isEmpty) _error = _message(error);
      });
    }
  }

  void _restoreCounts(String? raw) {
    if (raw == null) return;
    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      _conteo = decoded.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      );
      _computeRange();
    } catch (_) {}
  }

  void _restorePoints(String? raw) {
    if (raw == null) return;
    try {
      _setPoints(jsonDecode(raw) as List);
      _offlineData = true;
    } catch (_) {}
  }

  void _computeRange() {
    final positives = _conteo.values.where((value) => value > 0).toList();
    _min = positives.isEmpty ? 0 : positives.reduce((a, b) => a < b ? a : b);
    _max = positives.isEmpty ? 0 : positives.reduce((a, b) => a > b ? a : b);
  }

  void _rebuildPolygons() {
    _polygons.clear();
    for (final municipality in _municipios) {
      for (final ring in municipality.rings) {
        _polygons.add(
          Polygon(
            points: ring,
            isFilled: true,
            color: _colorFor(municipality.key),
            borderColor: (_conteo[municipality.key] ?? 0) > 0
                ? Colors.black.withValues(alpha: .24)
                : Colors.black12,
            borderStrokeWidth: .8,
            label: municipality.name,
          ),
        );
      }
    }
  }

  void _onMapEvent(MapEvent event) {
    final nextZoom = event.camera.zoom;
    if ((nextZoom - _zoom).abs() > .05 && mounted) {
      setState(() => _zoom = nextZoom);
    }
    if (event is! MapEventMoveEnd && event is! MapEventFlingAnimationEnd) {
      return;
    }
    _moveDebounce?.cancel();
    _moveDebounce = Timer(
      const Duration(milliseconds: 180),
      _loadVisiblePoints,
    );
  }

  Future<void> _loadVisiblePoints() async {
    if (!mounted || _loadingPoints) return;
    final camera = _map.camera;
    if (camera.zoom < _markerZoom) {
      if (_circles.isNotEmpty) setState(_circles.clear);
      return;
    }
    final bounds = camera.visibleBounds;
    setState(() => _loadingPoints = true);
    try {
      final response = await context.read<ApiClient>().dio.get(
        '/v1/mapa/data',
        queryParameters: {
          'estatus': 'validado',
          'limit': 900,
          'bbox':
              '${bounds.west},${bounds.south},${bounds.east},${bounds.north}',
        },
      );
      final raw = response.data is String
          ? jsonDecode(response.data)
          : response.data;
      final points = raw is Map ? (raw['data'] as List? ?? const []) : const [];
      _setPoints(points);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pointsCacheKey, jsonEncode(points));
      if (mounted) setState(() => _offlineData = false);
    } catch (_) {
      if (mounted) setState(() => _offlineData = true);
    } finally {
      if (mounted) setState(() => _loadingPoints = false);
    }
  }

  void _setPoints(List<dynamic> points) {
    _circles
      ..clear()
      ..addAll(
        points.take(900).map((raw) {
          final item = Map<String, dynamic>.from(raw as Map);
          final lat = (item['lat'] as num?)?.toDouble();
          final lng = (item['lng'] as num?)?.toDouble();
          if (lat == null || lng == null) return null;
          return CircleMarker(
            point: LatLng(lat, lng),
            radius: 4.5,
            color: const Color(0xFF7A0019).withValues(alpha: .82),
            borderColor: Colors.white,
            borderStrokeWidth: 1,
          );
        }).whereType<CircleMarker>(),
      );
  }

  Color _colorFor(String key) {
    final value = _conteo[key] ?? 0;
    if (_max <= 0 || value <= 0) return _scale.first.withValues(alpha: .9);
    if (_max == _min) return _scale.last.withValues(alpha: .85);
    final index =
        1 + (((value - _min) / (_max - _min)) * 4).clamp(0, 4).round();
    return _scale[index].withValues(alpha: .85);
  }

  void _handleTap(TapPosition _, LatLng point) {
    for (final municipality in _municipios) {
      for (final ring in municipality.rings) {
        if (!_pointInPolygon(point, ring)) continue;
        final count = _conteo[municipality.key] ?? 0;
        showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (_) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  municipality.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text('Clave: ${municipality.key}'),
                Text('Afiliados: $count'),
              ],
            ),
          ),
        );
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _conteo.values.fold<int>(0, (sum, value) => sum + value);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de afiliados'),
        actions: [
          if (!_loading)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  '$total',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: const LatLng(19.7, -101.2),
              initialZoom: 7,
              minZoom: 5,
              maxZoom: 18,
              onTap: _handleTap,
              onMapEvent: _onMapEvent,
            ),
            children: [
              _tileLayer,
              PolygonLayer(polygons: _polygons, polygonCulling: true),
              if (_circles.isNotEmpty) CircleLayer(circles: _circles),
            ],
          ),
          Positioned(
            right: 12,
            top: 12,
            child: _Legend(min: _min, max: _max, scale: _scale),
          ),
          if (_zoom < _markerZoom)
            const Positioned(
              left: 12,
              bottom: 12,
              child: _MapBadge(
                icon: Icons.zoom_in_map_rounded,
                text: 'Acércate para ver puntos',
              ),
            ),
          if (_offlineData)
            const Positioned(
              left: 12,
              top: 12,
              child: _MapBadge(
                icon: Icons.offline_pin_rounded,
                text: 'Datos guardados',
              ),
            ),
          if (_loadingPoints)
            const Positioned(
              right: 16,
              bottom: 16,
              child: SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          if (_loading)
            const Positioned.fill(
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_error!),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _message(Object error) {
    if (error is DioException) {
      if (error.response?.statusCode == 403) {
        return 'Tu cuenta no tiene permiso para consultar el mapa.';
      }
      if (error.response?.statusCode != null) {
        return 'No se pudo actualizar el mapa (${error.response!.statusCode}).';
      }
    }
    return 'No se pudo cargar el mapa.';
  }

  static bool _pointInPolygon(LatLng point, List<LatLng> ring) {
    var inside = false;
    for (int i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final xi = ring[i].longitude, yi = ring[i].latitude;
      final xj = ring[j].longitude, yj = ring[j].latitude;
      if (((yi > point.latitude) != (yj > point.latitude)) &&
          point.longitude <
              (xj - xi) *
                      (point.latitude - yi) /
                      ((yj - yi) == 0 ? 1e-12 : yj - yi) +
                  xi) {
        inside = !inside;
      }
    }
    return inside;
  }
}

class _MunGeom {
  const _MunGeom({required this.key, required this.name, required this.rings});
  final String key;
  final String name;
  final List<List<LatLng>> rings;

  factory _MunGeom.fromTransfer(Map<String, dynamic> raw) => _MunGeom(
    key: raw['key'] as String,
    name: raw['name'] as String,
    rings: (raw['rings'] as List)
        .map(
          (ring) => (ring as List).map((point) {
            final pair = point as List;
            return LatLng(
              (pair[1] as num).toDouble(),
              (pair[0] as num).toDouble(),
            );
          }).toList(),
        )
        .toList(),
  );
}

List<Map<String, dynamic>> _parseMunicipios(String source) {
  final geo = Map<String, dynamic>.from(jsonDecode(source) as Map);
  final output = <Map<String, dynamic>>[];
  for (final rawFeature in geo['features'] as List? ?? const []) {
    final feature = Map<String, dynamic>.from(rawFeature as Map);
    final properties = Map<String, dynamic>.from(
      feature['properties'] as Map? ?? const {},
    );
    final geometry = Map<String, dynamic>.from(
      feature['geometry'] as Map? ?? const {},
    );
    var key = '${properties['CVEGEO'] ?? ''}'.trim();
    if (key.length < 5) {
      final cve =
          '${properties['CVE_MUN'] ?? properties['CVE_MUNI'] ?? properties['CVE_MPIO'] ?? ''}'
              .trim();
      if (cve.isNotEmpty) key = '16${cve.padLeft(3, '0')}';
    }
    if (key.length < 5) continue;
    final name =
        '${properties['NOMGEO'] ?? properties['NOM_MUN'] ?? properties['NOM_MPIO'] ?? 'SIN NOMBRE'}';
    final coordinates = geometry['coordinates'];
    final rings = <dynamic>[];
    if (geometry['type'] == 'Polygon' &&
        coordinates is List &&
        coordinates.isNotEmpty) {
      rings.add(coordinates.first);
    } else if (geometry['type'] == 'MultiPolygon' && coordinates is List) {
      for (final polygon in coordinates) {
        if (polygon is List && polygon.isNotEmpty) rings.add(polygon.first);
      }
    }
    output.add({'key': key, 'name': name, 'rings': rings});
  }
  return output;
}

class _MapBadge extends StatelessWidget {
  const _MapBadge({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .92),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 17), const SizedBox(width: 6), Text(text)],
      ),
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.min, required this.max, required this.scale});
  final int min;
  final int max;
  final List<Color> scale;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Afiliados',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final color in scale)
                Container(
                  width: 18,
                  height: 12,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 6,
                  ),
                  color: color,
                ),
            ],
          ),
          Text(
            max > 0 ? '0 — $min … $max' : '0',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
