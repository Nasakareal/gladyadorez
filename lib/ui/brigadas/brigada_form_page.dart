import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../core/brand_theme.dart';
import '../../models/brigada.dart';
import '../../services/api_client.dart';
import '../../services/brigada_service.dart';

class BrigadaFormPage extends StatefulWidget {
  const BrigadaFormPage({super.key, this.brigade});
  final Brigada? brigade;

  @override
  State<BrigadaFormPage> createState() => _BrigadaFormPageState();
}

class _BrigadaFormPageState extends State<BrigadaFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _responsible = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  List<BrigadaSection> _sections = const [];
  int? _sectionId;
  bool _active = true;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  BrigadaService get _service => BrigadaService(context.read<ApiClient>());

  @override
  void initState() {
    super.initState();
    final brigade = widget.brigade;
    if (brigade != null) {
      _sectionId = brigade.section.id;
      _responsible.text = brigade.responsible;
      _phone.text = brigade.phone ?? '';
      _address.text = brigade.address ?? '';
      _notes.text = brigade.notes ?? '';
      _latitude.text = brigade.latitude.toStringAsFixed(7);
      _longitude.text = brigade.longitude.toStringAsFixed(7);
      _active = brigade.active;
    }
    _loadSections();
  }

  @override
  void dispose() {
    for (final controller in [
      _responsible,
      _phone,
      _address,
      _notes,
      _latitude,
      _longitude,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSections() async {
    try {
      final result = await _service.sections();
      if (mounted) {
        setState(() => _sections = result);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = BrigadaService.message(error));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _useLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception();
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() {
          _latitude.text = position.latitude.toStringAsFixed(7);
          _longitude.text = position.longitude.toStringAsFixed(7);
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo obtener tu ubicación. Revisa el permiso del teléfono.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _sectionId == null) return;
    setState(() => _saving = true);
    try {
      await _service.save(
        id: widget.brigade?.id,
        sectionId: _sectionId!,
        responsible: _responsible.text,
        phone: _phone.text,
        address: _address.text,
        notes: _notes.text,
        latitude: double.parse(_latitude.text),
        longitude: double.parse(_longitude.text),
        active: _active,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(BrigadaService.message(error))));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.brigade == null ? 'Nueva brigada' : 'Editar brigada'),
    ),
    body: GladyzBackdrop(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 10),
                  ],
                  GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Datos de la brigada',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<int>(
                          value: _sections.any((item) => item.id == _sectionId)
                              ? _sectionId
                              : null,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Sección de Morelia',
                          ),
                          items: _sections
                              .map(
                                (section) => DropdownMenuItem(
                                  value: section.id,
                                  child: Text(section.label),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _sectionId = value),
                          validator: (value) =>
                              value == null ? 'Selecciona una sección.' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _responsible,
                          decoration: const InputDecoration(
                            labelText: 'Responsable',
                          ),
                          validator: (value) => (value ?? '').trim().isEmpty
                              ? 'Escribe el responsable.'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Teléfono',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _address,
                          decoration: const InputDecoration(
                            labelText: 'Dirección o punto de reunión',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notes,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Indicaciones',
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _active,
                          onChanged: (value) => setState(() => _active = value),
                          title: const Text('Aceptar registros de asistencia'),
                          subtitle: Text(
                            _active ? 'Brigada activa' : 'Registro cerrado',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ubicación',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Usa la ubicación del teléfono en el punto de reunión.',
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _useLocation,
                          icon: const Icon(Icons.my_location_rounded),
                          label: const Text('Usar mi ubicación'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _latitude,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                      signed: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Latitud',
                                ),
                                validator: _coordinate,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _longitude,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                      signed: true,
                                    ),
                                decoration: const InputDecoration(
                                  labelText: 'Longitud',
                                ),
                                validator: _coordinate,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded),
                    label: Text(_saving ? 'Guardando…' : 'Guardar brigada'),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    ),
  );

  String? _coordinate(String? value) =>
      double.tryParse((value ?? '').trim()) == null ? 'Dato requerido.' : null;
}
