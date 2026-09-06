import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/brand_theme.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/avance_service.dart';

class AvancePage extends StatefulWidget {
  const AvancePage({super.key});

  @override
  State<AvancePage> createState() => _AvancePageState();
}

class _AvancePageState extends State<AvancePage> {
  final Map<String, dynamic> _filters = {};
  AvanceSnapshot? _snapshot;
  bool _loading = true;
  String? _error;

  AvanceService get _service => AvanceService(context.read<ApiClient>());

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
      final result = await _service.fetch(_filters);
      if (mounted) setState(() => _snapshot = result);
    } catch (error) {
      if (mounted) setState(() => _error = AvanceService.message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avance'),
        actions: [
          IconButton(
            tooltip: 'Personas convencidas',
            onPressed: _snapshot == null ? null : _openPeople,
            icon: const Icon(Icons.people_alt_rounded),
          ),
          IconButton(
            tooltip: 'Filtros',
            onPressed: _snapshot == null ? null : _openFilters,
            icon: Badge(
              isLabelVisible: _filters.isNotEmpty,
              label: Text('${_filters.length}'),
              child: const Icon(Icons.tune_rounded),
            ),
          ),
        ],
      ),
      body: GladyzBackdrop(child: _body()),
    );
  }

  Widget _body() {
    if (_loading && _snapshot == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _snapshot == null) {
      return Center(
        child: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(_error!),
        ),
      );
    }
    final snapshot = _snapshot!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          if (_error != null) ...[
            _MessagePanel(message: _error!),
            const SizedBox(height: 10),
          ],
          if (_filters.isNotEmpty) ...[
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final entry in _filters.entries)
                  InputChip(
                    label: Text(_filterLabel(entry.key, entry.value)),
                    onDeleted: () {
                      setState(() => _filters.remove(entry.key));
                      _load();
                    },
                  ),
                ActionChip(
                  avatar: const Icon(Icons.clear_all_rounded, size: 18),
                  label: const Text('Limpiar'),
                  onPressed: () {
                    setState(_filters.clear);
                    _load();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          _Totals(totals: snapshot.totals),
          const SizedBox(height: 12),
          _Rankings(snapshot: snapshot),
          const SizedBox(height: 12),
          Text(
            'Avance por municipio',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 9),
          if (snapshot.rows.isEmpty)
            const GlassPanel(
              child: Text('No hay datos con los filtros actuales.'),
            ),
          for (final row in snapshot.rows) ...[
            _MunicipalityCard(
              row: row,
              sections:
                  snapshot
                      .sectionsByScope['${row['cve_mun']}|${row['distrito_local']}'] ??
                  const [],
              canEdit: context.read<AuthService>().can('avance.metas'),
              onEdit: () => _editGoal(row),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Future<void> _editGoal(Map<String, dynamic> row) async {
    final convinced = TextEditingController(
      text: '${row['meta_convencidos'] ?? 0}',
    );
    final banners = TextEditingController(text: '${row['meta_lonas'] ?? 0}');
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Metas · ${row['municipio']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: convinced,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Meta de convencidos',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: banners,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Meta de lonas (opcional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (save != true || !mounted) return;
    final convincedValue = int.tryParse(convinced.text);
    if (convincedValue == null || convincedValue < 1) {
      _snack('La meta de convencidos debe ser mayor a cero.');
      return;
    }
    try {
      await _service.saveGoal(
        municipalityCode: '${row['cve_mun']}',
        localDistrict: _int(row['distrito_local']),
        convinced: convincedValue,
        banners: banners.text.trim().isEmpty
            ? null
            : int.tryParse(banners.text),
      );
      if (mounted) _snack('Meta guardada correctamente.');
      await _load();
    } catch (error) {
      if (mounted) _snack(AvanceService.message(error));
    }
  }

  Future<void> _openFilters() async {
    final snapshot = _snapshot!;
    final draft = Map<String, dynamic>.from(_filters);
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              18,
              18,
              18,
              MediaQuery.viewInsetsOf(context).bottom + 18,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Filtrar avance',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _dropdown(
                    'Distrito local',
                    'distrito_local',
                    snapshot.localDistricts,
                    draft,
                    setSheetState,
                  ),
                  _dropdown(
                    'Distrito federal',
                    'distrito_federal',
                    snapshot.federalDistricts,
                    draft,
                    setSheetState,
                  ),
                  _dropdown(
                    'Referente',
                    'referente',
                    snapshot.referents,
                    draft,
                    setSheetState,
                  ),
                  DropdownButtonFormField<String>(
                    value: draft['capturista_id']?.toString(),
                    decoration: const InputDecoration(labelText: 'Capturista'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Todos')),
                      for (final user in snapshot.capturers)
                        DropdownMenuItem(
                          value: '${user['id']}',
                          child: Text('${user['name']}'),
                        ),
                    ],
                    onChanged: (value) => setSheetState(
                      () => value == null || value.isEmpty
                          ? draft.remove('capturista_id')
                          : draft['capturista_id'] = value,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, draft),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Aplicar filtros'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _filters
        ..clear()
        ..addAll(result);
    });
    _load();
  }

  Widget _dropdown(
    String label,
    String key,
    List<String> values,
    Map<String, dynamic> draft,
    StateSetter setSheetState,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<String>(
      value: draft[key]?.toString(),
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: '', child: Text('Todos')),
        for (final value in values)
          DropdownMenuItem(value: value, child: Text(value)),
      ],
      onChanged: (value) => setSheetState(
        () => value == null || value.isEmpty
            ? draft.remove(key)
            : draft[key] = value,
      ),
    ),
  );

  void _openPeople() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => _PeoplePage(filters: Map<String, dynamic>.from(_filters)),
    ),
  );

  String _filterLabel(String key, dynamic value) {
    const labels = {
      'distrito_local': 'DL',
      'distrito_federal': 'DF',
      'referente': 'Referente',
      'capturista_id': 'Capturista',
    };
    return '${labels[key] ?? key}: $value';
  }

  void _snack(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

class _Totals extends StatelessWidget {
  const _Totals({required this.totals});
  final Map<String, dynamic> totals;

  @override
  Widget build(BuildContext context) => GlassPanel(
    tint: GladyzColors.granate,
    opacity: .9,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Resumen general',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 18,
          runSpacing: 14,
          children: [
            _Total(
              label: 'Convencidos',
              value: _int(totals['total_convencidos']),
              percent: _double(totals['porcentaje_convencidos']),
            ),
            _Total(
              label: 'Secciones cubiertas',
              value: _int(totals['secciones_cubiertas']),
              percent: _double(totals['porcentaje_secciones_cubiertas']),
            ),
            _Total(
              label: 'Lonas',
              value: _int(totals['total_lonas']),
              percent: _double(totals['porcentaje_lonas']),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Total extends StatelessWidget {
  const _Total({
    required this.label,
    required this.value,
    required this.percent,
  });
  final String label;
  final int value;
  final double percent;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 145,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          NumberFormat.decimalPattern('es_MX').format(value),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          '$label · ${percent.toStringAsFixed(1)}%',
          style: TextStyle(
            color: Colors.white.withValues(alpha: .75),
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

class _Rankings extends StatelessWidget {
  const _Rankings({required this.snapshot});
  final AvanceSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    if (snapshot.topCapturers.isEmpty && snapshot.topReferents.isEmpty) {
      return const SizedBox.shrink();
    }
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resultados destacados',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
          ),
          const SizedBox(height: 8),
          for (final item in snapshot.topCapturers.take(5))
            _ranking(
              Icons.workspace_premium_rounded,
              '${item['name']}',
              _int(item['total']),
            ),
          for (final item in snapshot.topReferents.take(5))
            _ranking(
              Icons.star_rounded,
              '${item['name']}',
              _int(item['total']),
            ),
        ],
      ),
    );
  }

  Widget _ranking(IconData icon, String name, int total) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: GladyzColors.dorado),
    title: Text(name),
    trailing: Text(
      '$total',
      style: const TextStyle(fontWeight: FontWeight.w900),
    ),
  );
}

class _MunicipalityCard extends StatelessWidget {
  const _MunicipalityCard({
    required this.row,
    required this.sections,
    required this.canEdit,
    required this.onEdit,
  });
  final Map<String, dynamic> row;
  final List<Map<String, dynamic>> sections;
  final bool canEdit;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => GlassPanel(
    child: ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: Text(
        '${row['municipio']}',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        'Distrito local ${row['distrito_local']} · ${row['secciones']} secciones',
      ),
      trailing: canEdit
          ? IconButton(
              tooltip: 'Editar metas',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_note_rounded),
            )
          : null,
      children: [
        _progress(
          'Convencidos',
          _int(row['total_convencidos']),
          _int(row['meta_convencidos']),
          GladyzColors.granate,
        ),
        const SizedBox(height: 12),
        _progress(
          'Lonas',
          _int(row['total_lonas']),
          _int(row['meta_lonas']),
          GladyzColors.dorado,
        ),
        if (sections.isNotEmpty) ...[
          const Divider(height: 28),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Votos / convencidos por sección',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 7),
          for (final section in sections)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('Sección ${section['seccion']}'),
              subtitle: Text(
                'Distrito federal ${section['distrito_federal'] ?? '—'}',
              ),
              trailing: Text(
                '${section['total'] ?? 0}',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
        ],
      ],
    ),
  );

  Widget _progress(String label, int value, int goal, Color color) {
    final ratio = goal <= 0 ? 0.0 : (value / goal).clamp(0, 1).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text('$value / ${goal == 0 ? 'Sin meta' : goal}'),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: ratio,
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
          color: color,
        ),
      ],
    );
  }
}

class _PeoplePage extends StatefulWidget {
  const _PeoplePage({required this.filters});
  final Map<String, dynamic> filters;

  @override
  State<_PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<_PeoplePage> {
  List<Map<String, dynamic>> _people = const [];
  String? _error;
  bool _loading = true;

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
      final result = await AvanceService(
        context.read<ApiClient>(),
      ).fetchPeople(widget.filters);
      final data = result['data'];
      if (mounted) {
        setState(
          () => _people = data is List
              ? data
                    .whereType<Map>()
                    .map((item) => Map<String, dynamic>.from(item))
                    .toList()
              : const [],
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = AvanceService.message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Personas convencidas')),
    body: GladyzBackdrop(
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: FilledButton(onPressed: _load, child: Text(_error!)),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: _people.length,
                separatorBuilder: (_, _) => const SizedBox(height: 9),
                itemBuilder: (_, index) {
                  final person = _people[index];
                  final name =
                      [
                            person['nombre'],
                            person['apellido_paterno'],
                            person['apellido_materno'],
                          ]
                          .where(
                            (part) => part != null && '$part'.trim().isNotEmpty,
                          )
                          .join(' ');
                  return GlassPanel(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        child: Icon(Icons.person_rounded),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${person['municipio'] ?? 'Sin municipio'} · Sección ${person['seccion'] ?? '—'}\nDL ${person['distrito_local'] ?? '—'} · DF ${person['distrito_federal'] ?? '—'}',
                      ),
                      trailing: Text(
                        '${person['referente'] ?? ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  );
                },
              ),
            ),
    ),
  );
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) =>
      GlassPanel(tint: Colors.orange, opacity: .2, child: Text(message));
}

int _int(dynamic value) => int.tryParse('$value') ?? 0;
double _double(dynamic value) => double.tryParse('$value') ?? 0;
