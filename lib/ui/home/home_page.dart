import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:dio/dio.dart';

import '../../services/auth_service.dart';
import '../../services/api_client.dart';
import '../actividades/calendar_page.dart';
import '../mapa/mapa_page.dart';

class HomePage extends StatefulWidget {
  /// Si quieres arrancar en otro tab, pásalo desde el Navigator:
  /// Navigator.pushNamed(context, '/home', arguments: 1); // 0=Dashboard, 1=Calendario, 2=Mapa, 3=Reportes
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Marca
  static const _granate = Color(0xFF7A0019);
  static const _humo = Color(0xFFF5F5F7);

  String? errorDevice;
  int _tab = 0; // 0=Dashboard, 1=Calendario, 2=Mapa, 3=Reportes

  // Páginas
  late final List<Widget> _pages = [
    _Dashboard(onGoCalendar: () => _setTab(1), onGoMap: () => _setTab(2)),
    const CalendarPage(),
    const MapaPage(),
    const _Placeholder(title: 'Reportes'),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Permite elegir tab inicial vía argumentos de ruta
    final arg = ModalRoute.of(context)?.settings.arguments;
    if (arg is int && arg >= 0 && arg < _pages.length) {
      _tab = arg;
    }
  }

  @override
  void initState() {
    super.initState();
    _registerDeviceToken();
    _wireForegroundNotifications();
  }

  Future<void> _registerDeviceToken() async {
    if (Firebase.apps.isEmpty) return;
    try {
      // Pide permiso (en iOS muestra prompt; en Android no pasa nada)
      await FirebaseMessaging.instance.requestPermission();

      final fcm = await FirebaseMessaging.instance.getToken();
      if (fcm != null && fcm.isNotEmpty) {
        await _sendDeviceToServer(fcm);
      }

      // Si FCM rota el token, lo volvemos a registrar
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        if (newToken.isNotEmpty) {
          await _sendDeviceToServer(newToken);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(
        () => errorDevice = _fmtDioError(
          e,
          fallback: 'No se pudo registrar el dispositivo para notificaciones',
        ),
      );
    }
  }

  Future<void> _sendDeviceToServer(String token) async {
    final api = context.read<ApiClient>();
    try {
      // El interceptor del ApiClient ya mete el Authorization: Bearer <token> si existe.
      await api.dio.post(
        '/v1/devices',
        data: {
          'token': token,
          'platform': Platform.isAndroid
              ? 'android'
              : (Platform.isIOS ? 'ios' : 'other'),
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(
        () => errorDevice = _fmtDioError(
          e,
          fallback: 'No se pudo registrar el dispositivo para notificaciones',
        ),
      );
    }
  }

  void _wireForegroundNotifications() {
    if (Firebase.apps.isEmpty) return;
    FirebaseMessaging.onMessage.listen((msg) {
      final n = msg.notification;
      if (!mounted || n == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _granate,
          behavior: SnackBarBehavior.floating,
          content: Row(
            children: [
              const Icon(
                Icons.notifications_active_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('${n.title ?? 'Notificación'} — ${n.body ?? ''}'),
              ),
            ],
          ),
        ),
      );
    });
  }

  void _setTab(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    final titles = const ['Dashboard', 'Calendario', 'Mapa', 'Reportes'];
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: _humo,
      appBar: AppBar(
        backgroundColor: _granate,
        elevation: 0,
        title: Text(
          titles[_tab],
          style: tt.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      drawer: _AppDrawer(
        currentTab: _tab,
        onSelectTab: (i) {
          Navigator.pop(context);
          _setTab(i);
        },
        onLogout: () async {
          await context.read<AuthService>().logout();
          if (context.mounted) Navigator.of(context).pushReplacementNamed('/');
        },
      ),
      body: Column(
        children: [
          if (errorDevice != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: const Color(0xFFFFF8E1),
              child: Text(
                errorDevice!,
                style: tt.bodyMedium?.copyWith(color: const Color(0xFF8D6E63)),
              ),
            ),
          Expanded(child: _pages[_tab]),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: _granate,
          boxShadow: [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _tab,
            onTap: _setTab,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white70,
            showUnselectedLabels: true,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_rounded),
                label: 'Dashboard',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_month_rounded),
                label: 'Calendario',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.map_rounded),
                label: 'Mapa',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_rounded),
                label: 'Reportes',
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _tab == 1
          ? FloatingActionButton.extended(
              backgroundColor: _granate,
              icon: const Icon(Icons.add),
              label: const Text('Actividad'),
              onPressed: () {
                // TODO: conectar al flujo de crear actividad
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Crear actividad (pendiente)')),
                );
              },
            )
          : null,
    );
  }

  String _fmtDioError(Object e, {required String fallback}) {
    if (e is DioException) {
      final sc = e.response?.statusCode;
      final data = e.response?.data;
      final body = data is String ? data : (data?.toString() ?? '');
      return '$fallback (HTTP ${sc ?? '-'}) $body';
    }
    return fallback;
  }
}

/// Landing sencillo con marca y accesos rápidos
class _Dashboard extends StatelessWidget {
  static const _granate = Color(0xFF7A0019);
  static const _granateOsc = Color(0xFF5C0013);
  static const _dorado = Color(0xFFF2C14E);

  final VoidCallback onGoCalendar;
  final VoidCallback onGoMap;
  const _Dashboard({required this.onGoCalendar, required this.onGoMap});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_granate, _granateOsc],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: tt.headlineSmall?.copyWith(color: Colors.white),
                    children: [
                      const TextSpan(
                        text: 'GLADY',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: .6,
                        ),
                      ),
                      TextSpan(
                        text: '•',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ).copyWith(color: _dorado),
                      ),
                      const TextSpan(
                        text: 'ADOREZ',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: .6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Michoacán que cumple',
                  style: tt.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: .9),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _QuickCard(
                  icon: Icons.calendar_month_rounded,
                  title: 'Calendario',
                  subtitle: 'Ver actividades',
                  onTap: onGoCalendar,
                ),
                _QuickCard(
                  icon: Icons.person_add_alt_1_rounded,
                  title: 'Afiliados',
                  subtitle: 'Captura y listado',
                  onTap: () {}, // TODO
                ),
                _QuickCard(
                  icon: Icons.map_rounded,
                  title: 'Mapa',
                  subtitle: 'Visualización territorial',
                  onTap: onGoMap,
                ),
                _QuickCard(
                  icon: Icons.bar_chart_rounded,
                  title: 'Reportes',
                  subtitle: 'Avance y ranking',
                  onTap: () {},
                ),
                _QuickCard(
                  icon: Icons.campaign_rounded,
                  title: 'Comunicados',
                  subtitle: 'Avisos y mensajes',
                  onTap: () => Navigator.pushNamed(context, '/comunicados'),
                ),
                _QuickCard(
                  icon: Icons.panorama_rounded,
                  title: 'Lonas',
                  subtitle: 'Captura, listado y mapa',
                  onTap: () => Navigator.pushNamed(context, '/lonas'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _QuickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 12 * 3) / 2,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF7A0019)),
              const SizedBox(height: 8),
              Text(
                title,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: tt.bodySmall?.copyWith(color: Colors.black54),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  static const _granate = Color(0xFF7A0019);
  static const _granateOsc = Color(0xFF5C0013);
  static const _dorado = Color(0xFFF2C14E);

  final int currentTab;
  final void Function(int) onSelectTab;
  final Future<void> Function() onLogout;

  const _AppDrawer({
    required this.currentTab,
    required this.onSelectTab,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_granate, _granateOsc],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: tt.titleLarge?.copyWith(color: Colors.white),
                      children: [
                        const TextSpan(
                          text: 'GLADY',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: .6,
                          ),
                        ),
                        TextSpan(
                          text: '•',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: _dorado,
                          ),
                        ),
                        const TextSpan(
                          text: 'ADOREZ',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: .6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Michoacán que cumple',
                    style: tt.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: .9),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            _drawerItem(
              icon: Icons.dashboard_rounded,
              label: 'Dashboard',
              selected: currentTab == 0,
              onTap: () => onSelectTab(0),
            ),
            _drawerItem(
              icon: Icons.calendar_month_rounded,
              label: 'Calendario',
              selected: currentTab == 1,
              onTap: () => onSelectTab(1),
            ),
            _drawerItem(
              icon: Icons.map_rounded,
              label: 'Mapa',
              selected: currentTab == 2,
              onTap: () => onSelectTab(2),
            ),
            _drawerItem(
              icon: Icons.bar_chart_rounded,
              label: 'Reportes',
              selected: currentTab == 3,
              onTap: () => onSelectTab(3),
            ),
            _drawerItem(
              icon: Icons.campaign_rounded,
              label: 'Comunicados',
              selected: false,
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/comunicados');
              },
            ),
            _drawerItem(
              icon: Icons.panorama_rounded,
              label: 'Lonas',
              selected: false,
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/lonas');
              },
            ),

            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.logout),
                  label: const Text('Salir'),
                  onPressed: () async => onLogout(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: _granate),
      title: Text(label),
      selected: selected,
      selectedTileColor: const Color(0x10FFFFFF),
      onTap: onTap,
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String title;
  const _Placeholder({required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('$title (próximamente)'));
  }
}
