import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand_theme.dart';
import '../../services/api_client.dart';

class ReportesPage extends StatefulWidget {
  const ReportesPage({super.key});

  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final Map<String, List<Map<String, dynamic>>> _data = {};
  final Set<String> _loading = {};
  String? _error;

  static const _reports = [
    ('afiliados', 'Afiliados'),
    ('secciones', 'Secciones'),
    ('capturistas', 'Capturistas'),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _reports.length, vsync: this);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) _load(_reports[_tabs.index].$1);
    });
    _load('afiliados');
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load(String report, {bool force = false}) async {
    if ((_data.containsKey(report) && !force) || _loading.contains(report)) {
      return;
    }
    setState(() {
      _loading.add(report);
      _error = null;
    });
    try {
      final response = await context.read<ApiClient>().dio.get(
        '/v1/reportes/$report',
      );
      final raw = response.data;
      final list = raw is List
          ? raw
          : raw is Map && raw['data'] is List
          ? raw['data'] as List
          : const [];
      if (mounted) {
        setState(
          () => _data[report] = list
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _loading.remove(report));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: GladyzColors.dorado,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [for (final report in _reports) Tab(text: report.$2)],
        ),
      ),
      body: GladyzBackdrop(
        child: TabBarView(
          controller: _tabs,
          children: [for (final report in _reports) _report(report.$1)],
        ),
      ),
    );
  }

  Widget _report(String key) {
    if (_loading.contains(key)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && !_data.containsKey(key)) {
      return Center(
        child: FilledButton.icon(
          onPressed: () => _load(key, force: true),
          icon: const Icon(Icons.refresh_rounded),
          label: Text(_error!),
        ),
      );
    }
    final items = _data[key] ?? const [];
    if (items.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load(key));
      return const Center(child: Text('Sin datos para mostrar.'));
    }
    final maximum = items.fold<double>(1, (max, item) {
      final total = double.tryParse('${item['total'] ?? 0}') ?? 0;
      return total > max ? total : max;
    });
    return RefreshIndicator(
      onRefresh: () => _load(key, force: true),
      child: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final item = items[index];
          final total = double.tryParse('${item['total'] ?? 0}') ?? 0;
          final label = key == 'secciones'
              ? 'Sección ${item['seccion'] ?? '—'}'
              : key == 'capturistas'
              ? '${item['name'] ?? 'Sin nombre'}'
              : '${item['label'] ?? item['estatus'] ?? 'Total'}';
          return GlassPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      '${total.toInt()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: GladyzColors.granate,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: total / maximum,
                    minHeight: 8,
                    backgroundColor: GladyzColors.granate.withValues(
                      alpha: .08,
                    ),
                    color: index.isEven
                        ? GladyzColors.granate
                        : GladyzColors.dorado,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _message(Object error) {
    if (error is DioException && error.response?.statusCode == 403) {
      return 'Reporte no disponible';
    }
    return 'No se pudo cargar. Reintentar';
  }
}
