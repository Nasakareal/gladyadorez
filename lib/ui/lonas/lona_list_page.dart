import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/lona.dart';
import '../../services/api_client.dart';
import '../../services/lona_service.dart';
import 'authenticated_image.dart';

class LonaListPage extends StatefulWidget {
  const LonaListPage({super.key});

  @override
  State<LonaListPage> createState() => _LonaListPageState();
}

class _LonaListPageState extends State<LonaListPage> {
  final _search = TextEditingController();
  final _seccion = TextEditingController();
  LonaPage? _page;
  bool _loading = true;
  String? _error;
  int _requestedPage = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _seccion.dispose();
    super.dispose();
  }

  Future<void> _load({int page = 1}) async {
    setState(() {
      _loading = true;
      _error = null;
      _requestedPage = page;
    });
    try {
      final result = await LonaService(
        context.read<ApiClient>(),
      ).fetchLonas(search: _search.text, seccion: _seccion.text, page: page);
      if (mounted) setState(() => _page = result);
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _load(page: _requestedPage),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
              child: Column(
                children: [
                  TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _load(),
                    decoration: const InputDecoration(
                      labelText: 'Dirección o responsable',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _seccion,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _load(),
                          decoration: const InputDecoration(
                            labelText: 'Sección',
                            prefixIcon: Icon(Icons.tag_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: _loading ? null : () => _load(),
                        icon: const Icon(Icons.filter_alt_rounded),
                        label: const Text('Filtrar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _ErrorState(message: _error!, retry: _load),
            )
          else if (_page == null || _page!.items.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('No hay lonas con estos filtros.')),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              sliver: SliverList.separated(
                itemCount: _page!.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) => _LonaCard(lona: _page!.items[index]),
              ),
            ),
            SliverToBoxAdapter(
              child: _Pager(
                page: _page!,
                previous: _loading || _page!.currentPage <= 1
                    ? null
                    : () => _load(page: _page!.currentPage - 1),
                next: _loading || _page!.currentPage >= _page!.lastPage
                    ? null
                    : () => _load(page: _page!.currentPage + 1),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _message(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) return '${data['message']}';
      if (error.response?.statusCode == 403) {
        return 'Tu usuario no tiene permiso para consultar lonas.';
      }
      if (error.response?.statusCode == 404) {
        return 'La API de lonas todavía no está disponible en el servidor.';
      }
    }
    return 'No se pudieron cargar las lonas. Revisa tu conexión.';
  }
}

class _LonaCard extends StatelessWidget {
  const _LonaCard({required this.lona});

  final Lona lona;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => _LonaDetail(lona: lona),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 118,
              height: 132,
              child: AuthenticatedImage(url: lona.fotoUrl),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sección ${lona.seccion}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      lona.direccion,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 7),
                    Text(
                      lona.responsable,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    if (lona.createdAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(lona.createdAt!),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LonaDetail extends StatelessWidget {
  const _LonaDetail({required this.lona});

  final Lona lona;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: AuthenticatedImage(url: lona.fotoUrl),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Lona #${lona.id} · Sección ${lona.seccion}',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            Text(lona.direccion),
            const SizedBox(height: 8),
            Text('Responsable: ${lona.responsable}'),
            if (lona.capturista != null) Text('Capturó: ${lona.capturista}'),
            const SizedBox(height: 8),
            SelectableText(
              '${lona.lat.toStringAsFixed(7)}, ${lona.lng.toStringAsFixed(7)}',
            ),
          ],
        ),
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({required this.page, this.previous, this.next});

  final LonaPage page;
  final VoidCallback? previous;
  final VoidCallback? next;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton.filledTonal(
            onPressed: previous,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Text(
            'Página ${page.currentPage} de ${page.lastPage} · ${page.total} lonas',
          ),
          IconButton.filledTonal(
            onPressed: next,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.retry});

  final String message;
  final Future<void> Function({int page}) retry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 52, color: Colors.black38),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => retry(),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
