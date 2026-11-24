import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/brand_theme.dart';
import '../../models/brigada.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/brigada_service.dart';
import '../lonas/authenticated_image.dart';
import 'brigada_form_page.dart';

class BrigadaDetailPage extends StatefulWidget {
  const BrigadaDetailPage({super.key, required this.brigadeId});
  final int brigadeId;
  @override
  State<BrigadaDetailPage> createState() => _BrigadaDetailPageState();
}

class _BrigadaDetailPageState extends State<BrigadaDetailPage> {
  Brigada? _brigade;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  XFile? _photo;
  final _notes = TextEditingController();
  BrigadaService get _service => BrigadaService(context.read<ApiClient>());

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.find(widget.brigadeId);
      if (mounted) setState(() => _brigade = result);
    } catch (error) {
      if (mounted) setState(() => _error = BrigadaService.message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick(ImageSource source) async {
    final selected = await ImagePicker().pickImage(
      source: source,
      imageQuality: 82,
      maxWidth: 1800,
    );
    if (selected != null && mounted) setState(() => _photo = selected);
  }

  Future<void> _attend() async {
    final brigade = _brigade;
    if (brigade == null || _photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Toma o selecciona una foto.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await _service.attend(brigade.id, _photo!, notes: _notes.text);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asistencia registrada correctamente.')),
      );
      setState(() {
        _photo = null;
        _notes.clear();
      });
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(BrigadaService.message(error))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _edit() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => BrigadaFormPage(brigade: _brigade)),
    );
    if (changed == true && mounted) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Detalle de brigada'),
      actions: [
        if (_brigade != null &&
            context.watch<AuthService>().can('brigadas.editar'))
          IconButton(
            onPressed: _edit,
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Editar',
          ),
      ],
    ),
    body: GladyzBackdrop(child: _body()),
  );

  Widget _body() {
    if (_loading && _brigade == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_brigade == null) {
      return Center(
        child: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: Text(_error ?? 'Reintentar'),
        ),
      );
    }
    final brigade = _brigade!;
    final canAttend = context.read<AuthService>().can('brigadas.participar');
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        brigade.section.label,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Icon(
                      brigade.active ? Icons.check_circle : Icons.lock,
                      color: brigade.active ? Colors.green : Colors.grey,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _line(Icons.person_rounded, brigade.responsible),
                if ((brigade.phone ?? '').isNotEmpty)
                  _line(Icons.phone_rounded, brigade.phone!),
                if ((brigade.address ?? '').isNotEmpty)
                  _line(Icons.location_on_rounded, brigade.address!),
                if ((brigade.notes ?? '').isNotEmpty)
                  _line(Icons.info_outline_rounded, brigade.notes!),
                const SizedBox(height: 8),
                Text(
                  '${brigade.attendanceCount} personas registraron asistencia',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    final url = brigade.googleMapsUrl;
                    if (url != null) {
                      launchUrl(
                        Uri.parse(url),
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                  icon: const Icon(Icons.directions_rounded),
                  label: const Text('Cómo llegar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (brigade.didAttend && brigade.myParticipation != null)
            _AttendanceDone(participation: brigade.myParticipation!)
          else if (!brigade.active)
            const GlassPanel(
              child: ListTile(
                leading: Icon(Icons.lock_rounded),
                title: Text('Registro cerrado'),
                subtitle: Text('Esta brigada ya no acepta asistencias.'),
              ),
            )
          else if (canAttend)
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Confirmar mi asistencia',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Toma una foto en la brigada. Sólo puedes registrarte una vez.',
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _sending
                              ? null
                              : () => _pick(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_rounded),
                          label: const Text('Cámara'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _sending
                              ? null
                              : () => _pick(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_rounded),
                          label: const Text('Galería'),
                        ),
                      ),
                    ],
                  ),
                  if (_photo != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              _photo!.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notes,
                    maxLength: 2000,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Comentario (opcional)',
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _sending ? null : _attend,
                      icon: _sending
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload_rounded),
                      label: Text(
                        _sending ? 'Subiendo…' : 'Subir foto y confirmar',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (brigade.participants.isNotEmpty) ...[
            const SizedBox(height: 12),
            GlassPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Personas que asistieron',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final item in brigade.participants)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(item.userName ?? 'Usuario'),
                      subtitle: Text(
                        item.attendedAt == null
                            ? ''
                            : DateFormat(
                                'dd/MM/yyyy HH:mm',
                              ).format(item.attendedAt!.toLocal()),
                      ),
                      trailing: item.evidenceUrl.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.photo_rounded),
                              onPressed: () => showDialog(
                                context: context,
                                builder: (_) => Dialog(
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: AuthenticatedImage(
                                      url: item.evidenceUrl,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _line(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _AttendanceDone extends StatelessWidget {
  const _AttendanceDone({required this.participation});
  final BrigadaParticipation participation;
  @override
  Widget build(BuildContext context) => GlassPanel(
    tint: Colors.green,
    opacity: .12,
    child: Column(
      children: [
        const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
        const SizedBox(height: 8),
        Text(
          'Tu asistencia está registrada',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        if (participation.attendedAt != null)
          Text(
            DateFormat(
              'dd/MM/yyyy HH:mm',
            ).format(participation.attendedAt!.toLocal()),
          ),
        if (participation.evidenceUrl.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: AuthenticatedImage(url: participation.evidenceUrl),
              ),
            ),
          ),
      ],
    ),
  );
}
