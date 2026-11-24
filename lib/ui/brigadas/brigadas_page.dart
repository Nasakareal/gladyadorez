import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand_theme.dart';
import '../../models/brigada.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/brigada_service.dart';
import 'brigada_detail_page.dart';
import 'brigada_form_page.dart';

class BrigadasPage extends StatefulWidget {
  const BrigadasPage({super.key});

  @override
  State<BrigadasPage> createState() => _BrigadasPageState();
}

class _BrigadasPageState extends State<BrigadasPage> {
  final _search = TextEditingController();
  BrigadaPage? _page;
  bool _loading = true;
  String? _error;
  int? _district;

  BrigadaService get _service => BrigadaService(context.read<ApiClient>());

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _service.fetch(
        search: _search.text,
        district: _district,
      );
      if (mounted) setState(() => _page = result);
    } catch (error) {
      if (mounted) setState(() => _error = BrigadaService.message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Brigada brigade) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BrigadaDetailPage(brigadeId: brigade.id),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _create() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const BrigadaFormPage()),
    );
    if (changed == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = context.watch<AuthService>().can('brigadas.crear');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brigadas de Morelia'),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nueva brigada'),
            )
          : null,
      body: GladyzBackdrop(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: GlassPanel(
                child: Column(
                  children: [
                    TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _load(),
                      decoration: InputDecoration(
                        labelText: 'Responsable o dirección',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          onPressed: _load,
                          icon: const Icon(Icons.arrow_forward_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int?>(
                      value: _district,
                      decoration: const InputDecoration(
                        labelText: 'Distrito local',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: null,
                          child: Text('Todos los distritos'),
                        ),
                        DropdownMenuItem(
                          value: 10,
                          child: Text('Distrito local 10'),
                        ),
                        DropdownMenuItem(
                          value: 11,
                          child: Text('Distrito local 11'),
                        ),
                        DropdownMenuItem(
                          value: 16,
                          child: Text('Distrito local 16'),
                        ),
                        DropdownMenuItem(
                          value: 17,
                          child: Text('Distrito local 17'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _district = value);
                        _load();
                      },
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading && _page == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _page == null) {
      return Center(
        child: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(_error!),
        ),
      );
    }
    final items = _page?.items ?? const <Brigada>[];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 110),
        children: [
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
          ],
          Text(
            '${_page?.total ?? 0} brigadas',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 9),
          if (items.isEmpty)
            const GlassPanel(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Center(child: Text('No hay brigadas con esos filtros.')),
              ),
            ),
          for (final brigade in items) ...[
            GlassPanel(
              onTap: () => _open(brigade),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          brigade.section.label,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                      _Status(active: brigade.active),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    brigade.responsible,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if ((brigade.address ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      brigade.address!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      Icon(
                        Icons.groups_rounded,
                        size: 19,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text('${brigade.attendanceCount} asistencias'),
                      const Spacer(),
                      if (brigade.didAttend)
                        const Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: Colors.green,
                              size: 19,
                            ),
                            SizedBox(width: 4),
                            Text('Ya asistí'),
                          ],
                        )
                      else if (brigade.active)
                        const Text(
                          'Registrar asistencia →',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.active});
  final bool active;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: active
          ? Colors.green.withValues(alpha: .12)
          : Colors.grey.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      active ? 'Activa' : 'Cerrada',
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: active ? Colors.green.shade800 : Colors.grey.shade700,
      ),
    ),
  );
}
