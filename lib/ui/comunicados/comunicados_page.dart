import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_client.dart';

class ComunicadosPage extends StatefulWidget {
  const ComunicadosPage({super.key});

  @override
  State<ComunicadosPage> createState() => _ComunicadosPageState();
}

class _ComunicadosPageState extends State<ComunicadosPage> {
  final _items = <Comunicado>[];
  int _page = 1;
  bool _loading = false;
  bool _end = false;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load(reset: true);
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200 &&
          !_loading &&
          !_end) {
        _load();
      }
    });
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final api = context.read<ApiClient>();
      final page = reset ? 1 : _page + 1;
      final res = await api.fetchComunicados(
        // Si quieres filtrar por municipio, pásalo aquí:
        // municipio: 'Morelia',
        page: page,
        limit: 20,
      );
      setState(() {
        if (reset) _items.clear();
        _items.addAll(res.items);
        _page = res.page;
        _end = _items.length >= res.total;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error cargando comunicados: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Comunicados')),
      body: RefreshIndicator(
        onRefresh: () => _load(reset: true),
        child: ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.all(12),
          itemCount: _items.length + 1,
          itemBuilder: (_, i) {
            if (i >= _items.length) {
              return _loading
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : const SizedBox.shrink();
            }
            final c = _items[i];
            final sub = c.contenido.replaceAll('\n', ' ');
            return Card(
              elevation: 1,
              child: ListTile(
                title: Text(
                  c.titulo,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  sub.length > 140 ? '${sub.substring(0, 140)}…' : sub,
                  maxLines: 3,
                ),
                onTap: () async {
                  // Si quieres detalle: navegar a otra vista o mostrar dialog
                  await showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(c.titulo),
                      content: SingleChildScrollView(child: Text(c.contenido)),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cerrar'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: _loading
          ? const SizedBox.shrink()
          : (!_end
                ? FloatingActionButton(
                    onPressed: _load,
                    child: const Icon(Icons.refresh),
                  )
                : null),
    );
  }
}
