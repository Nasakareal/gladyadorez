import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/lona.dart';
import '../../services/api_client.dart';
import '../../services/lona_service.dart';
import 'authenticated_image.dart';

class LonaMapPage extends StatefulWidget {
  const LonaMapPage({super.key});

  @override
  State<LonaMapPage> createState() => _LonaMapPageState();
}

class _LonaMapPageState extends State<LonaMapPage> {
  bool _loading = true;
  String? _error;
  List<Lona> _lonas = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lonas = await LonaService(context.read<ApiClient>()).fetchMapData();
      if (mounted) setState(() => _lonas = lonas);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error is DioException && error.response?.statusCode == 403
              ? 'Tu usuario no tiene permiso para consultar el mapa de lonas.'
              : 'No se pudo cargar el mapa de lonas.';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final points = _lonas
        .where((lona) => lona.lat.abs() <= 90 && lona.lng.abs() <= 180)
        .toList();
    return FlutterMap(
      options: const MapOptions(
        initialCenter: LatLng(19.7026, -101.1922),
        initialZoom: 8,
        minZoom: 5,
        maxZoom: 19,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'mx.utmorelia.sistemaAfiliadosApp',
        ),
        MarkerLayer(
          markers: points
              .map(
                (lona) => Marker(
                  point: LatLng(lona.lat, lona.lng),
                  width: 52,
                  height: 52,
                  child: IconButton.filled(
                    tooltip: 'Sección ${lona.seccion}',
                    onPressed: () => _showLona(lona),
                    icon: const Icon(Icons.panorama_rounded),
                  ),
                ),
              )
              .toList(),
        ),
        RichAttributionWidget(
          attributions: const [
            TextSourceAttribution('© OpenStreetMap contributors'),
          ],
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
                    Text(lona.direccion, maxLines: 3),
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
}
