import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/offline_sync_service.dart';
import '../../widgets/safe_osm_tile_layer.dart';

class LonaCapturePage extends StatefulWidget {
  const LonaCapturePage({super.key});

  @override
  State<LonaCapturePage> createState() => _LonaCapturePageState();
}

class _LonaCapturePageState extends State<LonaCapturePage> {
  static const _defaultPoint = LatLng(19.7026, -101.1922);

  final _formKey = GlobalKey<FormState>();
  final _seccion = TextEditingController();
  final _responsable = TextEditingController();
  final _direccion = TextEditingController();
  final _map = MapController();
  final _picker = ImagePicker();
  late final TileLayer _tileLayer;

  LatLng? _point;
  XFile? _photo;
  Uint8List? _preview;
  bool _locating = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tileLayer = buildSafeOpenStreetMapTileLayer(
      userAgentPackageName: 'mx.utmorelia.sistemaAfiliadosApp',
    );
  }

  @override
  void dispose() {
    _seccion.dispose();
    _responsable.dispose();
    _direccion.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _useMyLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const _FriendlyException(
          'Activa la ubicación del iPhone para continuar.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const _FriendlyException(
          'No hay permiso de ubicación. Puedes marcar el punto tocando el mapa.',
        );
      }
      // El GPS no necesita datos móviles. Mostramos primero la última posición
      // conocida y luego la afinamos con una lectura nueva cuando esté disponible.
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        _setPoint(LatLng(lastKnown.latitude, lastKnown.longitude), move: true);
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      _setPoint(LatLng(position.latitude, position.longitude), move: true);
    } catch (error) {
      if (mounted) {
        setState(() {
          if (_point != null) {
            _error =
                'Usando la última ubicación GPS guardada. Puedes ajustar el punto en el mapa.';
          } else {
            _error = error is _FriendlyException
                ? error.message
                : 'No se pudo obtener la ubicación. Marca el punto en el mapa.';
          }
        });
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _setPoint(LatLng point, {bool move = false}) {
    setState(() => _point = point);
    if (move) _map.move(point, 18);
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final photo = await _picker.pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1920,
      maxHeight: 1920,
      requestFullMetadata: false,
    );
    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    if (!mounted) return;
    setState(() {
      _photo = photo;
      _preview = bytes;
      _error = null;
    });
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_point == null) {
      setState(() => _error = 'Selecciona la ubicación exacta de la lona.');
      return;
    }
    if (_photo == null) {
      setState(() => _error = 'Toma o selecciona la foto de la lona puesta.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthService>();
      final ownerId = auth.user!.id;
      final sync = OfflineSyncService.instance;
      await sync.initialize(context.read<ApiClient>(), ownerId: ownerId);
      final lat = _point!.latitude.toStringAsFixed(7);
      final lng = _point!.longitude.toStringAsFixed(7);
      final result = await sync.submitLona(
        ownerId: ownerId,
        fields: {
          'seccion': _seccion.text.trim(),
          'direccion': _direccion.text.trim(),
          'responsable': _responsable.text.trim(),
          'lat': lat,
          'lng': lng,
          'ubicacion_google': 'https://www.google.com/maps?q=$lat,$lng',
        },
        photoPath: _photo!.path,
        photoName: _photo!.name.isEmpty ? 'lona.jpg' : _photo!.name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.queued
                ? 'Guardada sin conexión. Se subirá automáticamente al recuperar señal.'
                : 'Lona registrada correctamente.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = _apiMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Capturar lona')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            if (_error != null) ...[
              MaterialBanner(
                padding: const EdgeInsets.all(12),
                backgroundColor: const Color(0xFFFFE8E8),
                content: Text(_error!),
                actions: [
                  IconButton(
                    onPressed: () => setState(() => _error = null),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _seccion,
                    keyboardType: TextInputType.number,
                    maxLength: 10,
                    decoration: const InputDecoration(
                      labelText: 'Sección *',
                      prefixIcon: Icon(Icons.tag_rounded),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Es obligatoria'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _responsable,
                    maxLength: 150,
                    decoration: const InputDecoration(
                      labelText: 'Responsable *',
                      prefixIcon: Icon(Icons.person_rounded),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Es obligatorio'
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _direccion,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Dirección *',
                hintText: 'Calle, número, colonia, localidad y referencias',
                prefixIcon: Icon(Icons.home_work_rounded),
                alignLabelWithHint: true,
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'La dirección es obligatoria'
                  : null,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ubicación exacta *',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _locating ? null : _useMyLocation,
                  icon: _locating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded),
                  label: const Text('Mi ubicación'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 330,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: _defaultPoint,
                    initialZoom: 12,
                    minZoom: 5,
                    maxZoom: 19,
                    onTap: (_, point) => _setPoint(point),
                  ),
                  children: [
                    _tileLayer,
                    if (_point != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _point!,
                            width: 54,
                            height: 54,
                            child: const Icon(
                              Icons.location_pin,
                              size: 52,
                              color: Color(0xFF7A0019),
                            ),
                          ),
                        ],
                      ),
                    RichAttributionWidget(
                      attributions: const [
                        TextSourceAttribution('© OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _point == null
                  ? 'Toca el punto exacto en el mapa.'
                  : '${_point!.latitude.toStringAsFixed(7)}, ${_point!.longitude.toStringAsFixed(7)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            Text(
              'Foto de la lona puesta *',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (_preview != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.memory(_preview!, fit: BoxFit.cover),
                ),
              )
            else
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: const Color(0xFFECEFF1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 54,
                    color: Colors.black38,
                  ),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving
                        ? null
                        : () => _pickPhoto(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera_rounded),
                    label: const Text('Tomar foto'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _saving
                        ? null
                        : () => _pickPhoto(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Galería'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_alt_rounded),
          label: Text(
            _saving ? 'Guardando…' : 'Guardar lona (también offline)',
          ),
        ),
      ),
    );
  }

  String _apiMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final errors = data['errors'];
        if (errors is Map) {
          final messages = errors.values
              .expand((value) => value is List ? value : [value])
              .map((value) => '$value')
              .toList();
          if (messages.isNotEmpty) return messages.join('\n');
        }
        if (data['message'] != null) return '${data['message']}';
      }
      if (error.response?.statusCode == 413) {
        return 'La foto es demasiado grande. Toma otra foto e inténtalo de nuevo.';
      }
    }
    return 'No se pudo guardar la lona. Revisa tu conexión e inténtalo de nuevo.';
  }
}

class _FriendlyException implements Exception {
  const _FriendlyException(this.message);
  final String message;
}
