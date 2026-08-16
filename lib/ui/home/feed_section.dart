import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand_theme.dart';
import '../../models/feed_item.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/feed_service.dart';
import '../../widgets/offline_network_image.dart';

class FeedSection extends StatefulWidget {
  const FeedSection({super.key});

  @override
  State<FeedSection> createState() => FeedSectionState();
}

class FeedSectionState extends State<FeedSection> {
  final List<FeedItem> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _cached = false;
  String? _cursor;
  String? _error;
  int? _ownerId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ownerId = context.read<AuthService>().user?.id;
    if (ownerId != null && ownerId != _ownerId) {
      _ownerId = ownerId;
      refresh();
    }
  }

  Future<void> refresh() async {
    final ownerId = _ownerId;
    if (ownerId == null) return;
    final service = FeedService(context.read<ApiClient>());
    if (_items.isEmpty) {
      final cached = await service.cached(ownerId);
      if (mounted && cached.isNotEmpty) {
        setState(() {
          _items
            ..clear()
            ..addAll(cached);
          _cached = true;
          _loading = false;
        });
      }
    }

    try {
      final page = await service.fetch(ownerId: ownerId);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
        _cached = false;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cached = _items.isNotEmpty;
        _loading = false;
        _error = _items.isEmpty ? 'No se pudo cargar el feed.' : null;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _cursor == null) return;
    setState(() {
      _loadingMore = true;
      _error = null;
    });
    try {
      final page = await FeedService(
        context.read<ApiClient>(),
      ).fetch(ownerId: _ownerId!, cursor: _cursor);
      if (!mounted) return;
      final knownIds = _items.map((item) => item.id).toSet();
      setState(() {
        _items.addAll(page.items.where((item) => knownIds.add(item.id)));
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudieron cargar más publicaciones.');
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _requestNextPage() {
    if (_loadingMore || !_hasMore || _error != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadMore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final childCount = _items.length + 2;
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 30),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == 0) return _header(context);
            if (index <= _items.length) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: RepaintBoundary(
                  child: _FeedCard(item: _items[index - 1]),
                ),
              );
            }
            return _footer();
          },
          childCount: childCount,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: false,
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lonas recientes',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                'Capturas del equipo en campo',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (_cached)
          const Chip(
            visualDensity: VisualDensity.compact,
            avatar: Icon(Icons.offline_pin_rounded, size: 16),
            label: Text('Offline'),
          ),
        IconButton(
          onPressed: refresh,
          tooltip: 'Actualizar',
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
  );

  Widget _footer() {
    if (_loading && _items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_items.isEmpty && _error == null) {
      return const _FeedSurface(
        child: Text('Todavía no hay lonas publicadas.'),
      );
    }
    if (_error != null) {
      return Center(
        child: OutlinedButton.icon(
          onPressed: _items.isEmpty ? refresh : _loadMore,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(_error!),
        ),
      );
    }
    if (_hasMore) {
      _requestNextPage();
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 22),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Center(child: Text('Estás al día')),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.item});
  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    return _FeedSurface(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.pushNamed(context, '/lonas'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 14, 15, 11),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 21,
                    backgroundColor: GladyzColors.granate,
                    child: Text(
                      _initials(item.author),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          _date(item.createdAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.panorama_rounded,
                    color: GladyzColors.granate,
                  ),
                ],
              ),
            ),
            if (item.imageUrl != null)
              AspectRatio(
                aspectRatio: 1.18,
                child: OfflineNetworkImage(
                  url: item.imageUrl!,
                  api: context.read<ApiClient>(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 12, 15, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (item.body.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      item.body,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (item.meta.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Responsable: ${item.meta}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: GladyzColors.granate,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2);
    return parts.map((part) => part[0].toUpperCase()).join();
  }

  static String _date(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]} · $hour:$minute';
  }
}

class _FeedSurface extends StatelessWidget {
  const _FeedSurface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .82),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.white.withValues(alpha: .92)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x12000000),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Material(
        color: Colors.transparent,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}
