import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';

class MapaPage extends StatefulWidget {
  const MapaPage({super.key});
  @override
  State<MapaPage> createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
  // Geometrías por municipio (solo anillos exteriores)
  final List<_MunGeom> _municipios = [];
  // Capas
  final List<Polygon> _polys = [];
  final List<Marker> _markers = [];

  Map<String, int> _conteo = {};
  int _min = 0, _max = 0;
  bool _loading = true;
  String? _error;

  static const List<Color> _scale = [
    Color(0xffe9ecef), // cero
    Color(0xffcce5d0),
    Color(0xff99cfaa),
    Color(0xff66b985),
    Color(0xff2ea15e),
    Color(0xff0b8043),
  ];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiClient>();
      // 1) GeoJSON local (aunque el archivo sea .json)
      final geoStr = await rootBundle.loadString('assets/geo/michoacan.json');
      final geo = jsonDecode(geoStr) as Map<String, dynamic>;
      final feats = (geo['features'] as List).cast<Map<String, dynamic>>();

      // 2) Conteo por CVEGEO (USA ApiClient con Bearer y baseUrl)
      final conteoRes = await api.dio.get('/v1/mapa');
      final conteoData = conteoRes.data is String
          ? jsonDecode(conteoRes.data)
          : conteoRes.data;
      final conteoRaw =
          (conteoData['conteo'] as Map?)?.cast<String, dynamic>() ?? {};
      _conteo = conteoRaw.map((k, v) => MapEntry(k, (v as num).toInt()));

      // 3) Parse features -> municipios
      for (final f in feats) {
        final props = (f['properties'] as Map?) ?? {};
        final geom = (f['geometry'] as Map?) ?? {};
        final type = (geom['type'] as String?) ?? '';
        final coords = geom['coordinates'];

        String? cvegeo = _readCvegeo(props);
        String nombre = _readNombre(props) ?? 'SIN NOMBRE';
        if (cvegeo == null) {
          final cve3 = _readCve3(props);
          if (cve3 != null) cvegeo = '16${cve3.padLeft(3, '0')}';
        }
        if (cvegeo == null) continue;

        final rings = <List<LatLng>>[];
        if (type == 'Polygon') {
          final List outer = (coords as List).isNotEmpty ? coords[0] : const [];
          rings.add(_toLatLngList(outer));
        } else if (type == 'MultiPolygon') {
          for (final poly in (coords as List)) {
            final List outer = (poly as List).isNotEmpty ? poly[0] : const [];
            rings.add(_toLatLngList(outer));
          }
        } else {
          continue;
        }

        _municipios.add(_MunGeom(key: cvegeo, nombre: nombre, rings: rings));
      }

      // 4) Min/Max
      final positivos = _conteo.values.where((v) => v > 0).toList();
      if (positivos.isNotEmpty) {
        _min = positivos.reduce((a, b) => a < b ? a : b);
        _max = positivos.reduce((a, b) => a > b ? a : b);
      }

      // 5) Construir polígonos
      _polys.clear();
      for (final m in _municipios) {
        final fill = _colorFor(m.key);
        final stroke = _strokeFor(m.key);
        for (final ring in m.rings) {
          _polys.add(
            Polygon(
              points: ring,
              isFilled: true,
              color: fill,
              borderColor: stroke,
              borderStrokeWidth: 1.2,
              label: m.nombre,
            ),
          );
        }
      }

      // 6) Marcadores (puntos). El backend puede devolver lista directa o {data:[...]}
      try {
        final markRes = await api.dio.get(
          '/v1/mapa/data',
          queryParameters: {'estatus': 'validado', 'limit': 500},
        );
        final raw = markRes.data;
        final list = raw is String ? jsonDecode(raw) : raw;
        final puntos = list is Map<String, dynamic>
            ? (list['data'] as List?)
            : list;

        _markers.clear();
        if (puntos is List) {
          for (final e in puntos) {
            final lat = (e['lat'] as num?)?.toDouble();
            final lng = (e['lng'] as num?)?.toDouble();
            if (lat == null || lng == null) continue;
            final nombre = (e['nombre'] ?? '') as String;
            final ap = (e['apellido_paterno'] ?? '') as String;
            final am = (e['apellido_materno'] ?? '') as String;
            final muni = (e['municipio'] ?? '') as String;
            final full = [
              nombre,
              ap,
              am,
            ].where((s) => s.trim().isNotEmpty).join(' ');
            _markers.add(
              Marker(
                point: LatLng(lat, lng),
                width: 28,
                height: 28,
                child: Tooltip(
                  message: '$full\n$muni',
                  child: const Icon(Icons.location_on, size: 24),
                ),
              ),
            );
          }
        }
      } catch (_) {
        // puntos son opcionales; no romper si falla
      }

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      String msg = 'Error al cargar el mapa.';
      if (e is DioException) {
        final sc = e.response?.statusCode;
        final raw = e.message ?? '';
        if (sc == 401) {
          msg = '401 No autorizado: token inválido/expirado.';
        } else if (sc == 403) {
          msg = '403 Sin permiso: falta "mapa.ver".';
        } else if (raw.toLowerCase().contains('handshake') ||
            raw.toLowerCase().contains('certificate')) {
          msg = 'Problema SSL del servidor (handshake/certificate).';
        } else if (sc != null) {
          msg = 'HTTP $sc al cargar mapa.';
        }
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = msg;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // Helpers
  static String? _readNombre(Map props) {
    return (props['NOMGEO'] ??
            props['NOM_MUN'] ??
            props['NOM_MPIO'] ??
            props['NOMMUN'])
        as String?;
  }

  static String? _readCvegeo(Map props) {
    final raw = props['CVEGEO'];
    if (raw == null) return null;
    final s = raw.toString().trim();
    return s.length >= 5 ? s : null;
    // Ej: '16001'
  }

  static String? _readCve3(Map props) {
    return (props['CVE_MUN'] ?? props['CVE_MUNI'] ?? props['CVE_MPIO'])
        ?.toString();
  }

  static List<LatLng> _toLatLngList(List rawRing) {
    final out = <LatLng>[];
    for (final p in rawRing) {
      if (p is List && p.length >= 2) {
        final lng = (p[0] as num).toDouble();
        final lat = (p[1] as num).toDouble();
        out.add(LatLng(lat, lng));
      }
    }
    return out;
  }

  Color _colorFor(String key) {
    final v = _conteo[key] ?? 0;
    if (_max <= 0 || v <= 0) {
      return _scale[0].withValues(alpha: 0.9);
    }
    final steps = _scale.length - 1; // 1..5
    final t = (v - _min) / (_max - _min);
    final idx =
        1 + (t * (steps - 1)).clamp(0.0, (steps - 1).toDouble()).round();
    return _scale[idx].withValues(alpha: 0.85);
  }

  Color _strokeFor(String key) {
    final v = _conteo[key] ?? 0;
    return v > 0 ? Colors.black.withValues(alpha: 0.25) : Colors.black12;
  }

  void _handleTap(TapPosition _, LatLng latlng) {
    // hit test simple: primer polígono que contenga el punto
    for (final m in _municipios) {
      for (final ring in m.rings) {
        if (_pointInPolygon(latlng, ring)) {
          final total = _conteo[m.key] ?? 0;
          showModalBottomSheet(
            context: context,
            showDragHandle: true,
            builder: (_) => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.nombre,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Clave: ${m.key}'),
                  Text('Afiliados: $total'),
                  if (_max > 0 && total > 0) Text('Rango: $_min – $_max'),
                ],
              ),
            ),
          );
          return;
        }
      }
    }
  }

  // Ray casting
  static bool _pointInPolygon(LatLng pt, List<LatLng> ring) {
    bool inside = false;
    for (int i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final xi = ring[i].longitude, yi = ring[i].latitude;
      final xj = ring[j].longitude, yj = ring[j].latitude;
      final intersect =
          ((yi > pt.latitude) != (yj > pt.latitude)) &&
          (pt.longitude <
              (xj - xi) *
                      (pt.latitude - yi) /
                      ((yj - yi) == 0 ? 1e-12 : (yj - yi)) +
                  xi);
      if (intersect) inside = !inside;
    }
    return inside;
  }

  @override
  Widget build(BuildContext context) {
    final total = _conteo.values.fold<int>(0, (a, b) => a + b);
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Afiliados — Michoacán'),
        actions: [
          if (!_loading)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  'Totales: $total',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(19.7, -101.2),
              initialZoom: 7.0,
              minZoom: 5.0,
              maxZoom: 18.0,
              onTap: _handleTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'mx.utmorelia.sistema_afiliados_app',
                retinaMode: true,
              ),
              PolygonLayer(polygons: _polys),
              if (_markers.isNotEmpty) MarkerLayer(markers: _markers),
            ],
          ),
          Positioned(
            right: 12,
            top: 12,
            child: _Legend(min: _min, max: _max, scale: _scale),
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
                color: const Color(0xFFFFF3E0),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: tt.bodyMedium?.copyWith(
                      color: const Color(0xFF8D6E63),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MunGeom {
  final String key; // '16xxx'
  final String nombre;
  final List<List<LatLng>> rings;
  _MunGeom({required this.key, required this.nombre, required this.rings});
}

class _Legend extends StatelessWidget {
  final int min, max;
  final List<Color> scale;
  const _Legend({required this.min, required this.max, required this.scale});

  @override
  Widget build(BuildContext context) {
    return Card(
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
                _box(scale[0]),
                for (int i = 1; i < scale.length; i++) _box(scale[i]),
              ],
            ),
            Text(
              max > 0 ? '0  —  $min  …  $max' : '0',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _box(Color c) => Container(
    width: 18,
    height: 12,
    margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
    decoration: BoxDecoration(
      color: c,
      border: Border.all(color: Colors.black12),
    ),
  );
}
