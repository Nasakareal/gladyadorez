import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/lona.dart';
import '../../services/api_client.dart';
import '../../services/lona_service.dart';
import '../../widgets/safe_osm_tile_layer.dart';
import 'authenticated_image.dart';

class LonaMapPage extends StatefulWidget {
  const LonaMapPage({super.key});

  @override
  State<LonaMapPage> createState() => _LonaMapPageState();
}

class _LonaMapPageState extends State<LonaMapPage> {
  static const _cacheKey = 'lonas_map_last_view_v2';
  static const _minimumZoom = 8.0;
  static const _limit = 180;

  final _map = MapController();
  late final TileLayer _tileLayer;
  Timer? _debounce;
  CancelToken? _cancelToken;
  List<Lona> _lonas = const [];
  bool _loading = false;
  bool _offline = false;
  double _zoom = 8;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tileLayer = buildSafeOpenStreetMapTileLayer(
      userAgentPackageName: 'mx.utmorelia.sistemaAfiliadosApp',
    );
    _restoreCache();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadVisible());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cancelToken?.cancel('Mapa cerrado');
    _map.dispose();
    super.dispose();
  }

  Future<void> _restoreCache() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final raw = jsonDecode(prefs.getString(_cacheKey) ?? '[]') as List;
      final cached = raw
          .map((item) => Lona.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
      if (mounted && cached.isNotEmpty) {
        setState(() {
          _lonas = cached;
          _offline = true;
        });
      }
    } catch (_) {}
  }

  void _onMapEvent(MapEvent event) {
    final zoom = event.camera.zoom;
    if ((zoom - _zoom).abs() > .05 && mounted) setState(() => _zoom = zoom);
    if (zoom < _minimumZoom) {
      _cancelToken?.cancel('Zoom lejano');
      if (_lonas.isNotEmpty) setState(() => _lonas = const []);
      return;
    }
    if (event is! MapEventMoveEnd && event is! MapEventFlingAnimationEnd) {
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), _loadVisible);
  }

  Future<void> _loadVisible() async {
    if (!mounted || _map.camera.zoom < _minimumZoom) return;
    final bounds = _map.camera.visibleBounds;
    final bbox =
        '${bounds.west},${bounds.south},${bounds.east},${bounds.north}';
    _cancelToken?.cancel('Nueva zona visible');
    final cancelToken = CancelToken();
    _cancelToken = cancelToken;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lonas = await LonaService(
        context.read<ApiClient>(),
      ).fetchMapData(bbox: bbox, limit: _limit, cancelToken: cancelToken);
      if (!mounted || cancelToken.isCancelled) return;
      setState(() {
        _lonas = lonas;
        _offline = false;
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        jsonEncode(lonas.map(_cachePayload).toList()),
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error)) return;
      if (!mounted) return;
      setState(() {
        _offline = _lonas.isNotEmpty;
        _error = error.response?.statusCode == 403
            ? 'Tu usuario no tiene permiso para consultar este mapa.'
            : _lonas.isEmpty
            ? 'No se pudo cargar esta zona.'
            : null;
      });
    } finally {
      if (mounted && identical(_cancelToken, cancelToken)) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final markers = _lonas
        .where((lona) => lona.lat.abs() <= 90 && lona.lng.abs() <= 180)
        .map(
          (lona) => Marker(
            point: LatLng(lona.lat, lona.lng),
            width: 32,
            height: 32,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _showLona(lona),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFF7A0019).withValues(alpha: .9),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Color(0x33000000), blurRadius: 5),
                  ],
                ),
                child: const Icon(
                  Icons.panorama_rounded,
                  size: 17,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        )
        .toList(growable: false);

    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: const LatLng(19.7026, -101.1922),
            initialZoom: 8,
            minZoom: 5,
            maxZoom: 19,
            onMapEvent: _onMapEvent,
          ),
          children: [
            _tileLayer,
            if (markers.isNotEmpty) MarkerLayer(markers: markers),
            RichAttributionWidget(
              attributions: const [
                TextSourceAttribution('© OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        if (_zoom < _minimumZoom)
          const Positioned(
            left: 12,
            bottom: 12,
            child: _Badge(
              icon: Icons.zoom_in_rounded,
              text: 'Acércate para ver lonas',
            ),
          )
        else
          Positioned(
            left: 12,
            bottom: 12,
            child: _Badge(
              icon: _offline
                  ? Icons.offline_pin_rounded
                  : Icons.panorama_rounded,
              text: _offline
                  ? '${_lonas.length} lonas guardadas'
                  : '${_lonas.length}${_lonas.length >= _limit ? '+' : ''} en esta zona',
            ),
          ),
        if (_loading)
          const Positioned(
            right: 16,
            top: 16,
            child: SizedBox.square(
              dimension: 25,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
        if (_error != null)
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: MaterialBanner(
              content: Text(_error!),
              actions: [
                TextButton(
                  onPressed: _loadVisible,
                  child: const Text('REINTENTAR'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _showLona(Lona lona) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: AuthenticatedImage(url: lona.fotoUrl),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sección ${lona.seccion}',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      lona.direccion,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text('Responsable: ${lona.responsable}'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Map<String, dynamic> _cachePayload(Lona lona) => {
    'id': lona.id,
    'seccion': lona.seccion,
    'direccion': lona.direccion,
    'responsable': lona.responsable,
    'lat': lona.lat,
    'lng': lona.lng,
    'foto_url': lona.fotoUrl,
    'capturista': lona.capturista == null ? null : {'name': lona.capturista},
    'created_at': lona.createdAt?.toIso8601String(),
  };
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .92),
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [BoxShadow(color: Color(0x18000000), blurRadius: 8)],
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    ),
  );
}
