import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand_theme.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/offline_sync_service.dart';
import 'feed_section.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _deviceError;
  int? _syncOwnerId;
  final _feedKey = GlobalKey<FeedSectionState>();

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && Firebase.apps.isNotEmpty) {
      _registerDeviceToken();
      _wireForegroundNotifications();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ownerId = context.read<AuthService>().user?.id;
    if (ownerId != null && ownerId != _syncOwnerId) {
      _syncOwnerId = ownerId;
      OfflineSyncService.instance.initialize(
        context.read<ApiClient>(),
        ownerId: ownerId,
      );
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      context.read<AuthService>().restoreSession(),
      OfflineSyncService.instance.flush(),
      if (_feedKey.currentState != null) _feedKey.currentState!.refresh(),
    ]);
  }

  Future<void> _registerDeviceToken() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) await _sendDevice(token);
      FirebaseMessaging.instance.onTokenRefresh.listen(_sendDevice);
    } catch (error) {
      if (mounted) setState(() => _deviceError = _message(error));
    }
  }

  Future<void> _sendDevice(String token) async {
    if (kIsWeb) return;
    try {
      await context.read<ApiClient>().dio.post(
        '/v1/devices',
        data: {
          'token': token,
          'platform': Platform.isAndroid
              ? 'android'
              : Platform.isIOS
              ? 'ios'
              : 'other',
        },
      );
    } catch (error) {
      if (mounted) setState(() => _deviceError = _message(error));
    }
  }

  void _wireForegroundNotifications() {
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (!mounted || notification == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: GladyzColors.granate,
          content: Text(
            '${notification.title ?? 'Notificación'} — ${notification.body ?? ''}',
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final modules = _modules(auth);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: GladyzColors.granate.withValues(alpha: .84),
        title: const _Wordmark(),
      ),
      drawer: _AppDrawer(modules: modules),
      body: GladyzBackdrop(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              cacheExtent: 500,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 18, 14, 0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      GlassPanel(
                        tint: GladyzColors.granate,
                        opacity: .9,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hola, ${auth.user?.name.split(' ').first ?? ''}',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Lo que está colocando el equipo en Michoacán',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .82),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_deviceError != null) ...[
                        const SizedBox(height: 10),
                        GlassPanel(
                          tint: GladyzColors.dorado,
                          opacity: .22,
                          child: Row(
                            children: [
                              const Icon(Icons.notifications_off_outlined),
                              const SizedBox(width: 10),
                              Expanded(child: Text(_deviceError!)),
                              IconButton(
                                onPressed: () =>
                                    setState(() => _deviceError = null),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const _OfflineSyncBanner(),
                    ]),
                  ),
                ),
                if (auth.can('lonas.ver'))
                  FeedSection(key: _feedKey)
                else
                  const SliverPadding(
                    padding: EdgeInsets.all(14),
                    sliver: SliverToBoxAdapter(
                      child: GlassPanel(
                        child: Text(
                          'Tu cuenta no tiene acceso al feed de lonas.',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_Module> _modules(AuthService auth) {
    final all = [
      const _Module(
        'Afiliados',
        'Registro, consulta y seguimiento',
        Icons.people_alt_rounded,
        '/afiliados',
        'afiliados.ver',
      ),
      const _Module(
        'Secciones',
        'Catálogo territorial',
        Icons.grid_view_rounded,
        '/secciones',
        'secciones.ver',
      ),
      const _Module(
        'Calendario',
        'Agenda y actividades',
        Icons.calendar_month_rounded,
        '/calendario',
        'actividades.ver',
      ),
      const _Module(
        'Mapa',
        'Visualización territorial',
        Icons.map_rounded,
        '/mapa',
        'mapa.ver',
      ),
      const _Module(
        'Reportes',
        'Avances y resultados',
        Icons.bar_chart_rounded,
        '/reportes',
        'reportes.ver',
      ),
      const _Module(
        'Avance',
        'Metas, convencidos y lonas',
        Icons.trending_up_rounded,
        '/avance',
        'avance.ver',
      ),
      const _Module(
        'Comunicados',
        'Avisos y mensajes',
        Icons.campaign_rounded,
        '/comunicados',
        'comunicados.ver',
      ),
      const _Module(
        'Lonas',
        'Captura, listado y mapa',
        Icons.panorama_rounded,
        '/lonas',
        'lonas.ver',
      ),
      const _Module(
        'Administración',
        'Usuarios, roles y configuración',
        Icons.admin_panel_settings_rounded,
        '/admin',
        '_admin',
      ),
    ];
    return all.where((module) {
      if (module.permission == '_admin') {
        return auth.canAny([
          'usuarios.ver',
          'roles.ver',
          'permisos.ver',
          'settings.ver',
        ]);
      }
      return auth.can(module.permission);
    }).toList();
  }

  String _message(Object error) {
    if (error is DioException && error.response?.statusCode == 403) {
      return 'Las notificaciones no están disponibles para esta cuenta.';
    }
    return 'No se pudieron activar las notificaciones.';
  }
}

class _OfflineSyncBanner extends StatelessWidget {
  const _OfflineSyncBanner();

  @override
  Widget build(BuildContext context) {
    final sync = OfflineSyncService.instance;
    return ValueListenableBuilder<int>(
      valueListenable: sync.pendingCount,
      builder: (context, pending, _) => ValueListenableBuilder<bool>(
        valueListenable: sync.offline,
        builder: (context, offline, _) {
          if (pending == 0 && !offline) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 10),
            child: GlassPanel(
              tint: offline ? GladyzColors.dorado : Colors.white,
              opacity: offline ? .28 : .7,
              child: Row(
                children: [
                  Icon(
                    offline
                        ? Icons.cloud_off_rounded
                        : Icons.cloud_upload_rounded,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      pending > 0
                          ? '$pending captura${pending == 1 ? '' : 's'} pendiente${pending == 1 ? '' : 's'}. Se subirán automáticamente.'
                          : 'Sin conexión. Puedes seguir capturando.',
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sincronizar ahora',
                    onPressed: sync.flush,
                    icon: const Icon(Icons.sync_rounded),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Module {
  const _Module(
    this.title,
    this.subtitle,
    this.icon,
    this.route,
    this.permission,
  );
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final String permission;
}

class HomeModuleCard extends StatelessWidget {
  const HomeModuleCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String route;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      onTap: () => Navigator.pushNamed(context, route),
      padding: const EdgeInsets.all(15),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 126),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: GladyzColors.granate.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: GladyzColors.granate),
            ),
            const SizedBox(height: 18),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer({required this.modules});
  final List<_Module> modules;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    return Drawer(
      backgroundColor: Colors.transparent,
      child: GladyzBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: GlassPanel(
                  tint: GladyzColors.granate,
                  opacity: .9,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Wordmark(),
                      const SizedBox(height: 13),
                      Text(
                        auth.user?.name ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        auth.user?.email ?? '',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .72),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: [
                    ListTile(
                      leading: const Icon(Icons.home_rounded),
                      title: const Text('Inicio'),
                      onTap: () => Navigator.pop(context),
                    ),
                    for (final module in modules)
                      ListTile(
                        leading: Icon(module.icon),
                        title: Text(module.title),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, module.route);
                        },
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Cerrar sesión'),
                onTap: () async {
                  await context.read<AuthService>().logout();
                  if (context.mounted) {
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/login', (_) => false);
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) => Text.rich(
    const TextSpan(
      children: [
        TextSpan(
          text: 'GLADY',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .5),
        ),
        TextSpan(
          text: '•',
          style: TextStyle(
            color: GladyzColors.dorado,
            fontWeight: FontWeight.w900,
          ),
        ),
        TextSpan(
          text: 'ADOREZ',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: .5),
        ),
      ],
    ),
  );
}
