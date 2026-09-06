import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/constants.dart';
import 'core/brand_theme.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/push_service.dart';
import 'ui/auth/auth_gate.dart';
import 'ui/auth/login_page.dart';
import 'ui/home/home_page.dart';
import 'ui/comunicados/comunicados_page.dart';
import 'ui/lonas/lona_capture_page.dart';
import 'ui/lonas/lonas_page.dart';
import 'ui/afiliados/afiliados_page.dart';
import 'ui/secciones/secciones_page.dart';
import 'ui/actividades/actividades_page.dart';
import 'ui/reportes/reportes_page.dart';
import 'ui/admin/admin_pages.dart';
import 'ui/mapa/mapa_page.dart';
import 'ui/actividades/calendar_page.dart';
import 'ui/avance/avance_page.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBg(RemoteMessage message) async {
  // Manejo opcional de mensajes en segundo plano
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  final isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  if (isMobile) {
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseBg);
      await PushService.instance.init();
    } catch (error) {
      // La app debe seguir abriendo aunque falte la configuración nativa de
      // Firebase; únicamente quedan desactivadas las notificaciones push.
      debugPrint('Firebase no disponible: $error');
    }
  }

  runApp(const AfiliadosApp());
}

class AfiliadosApp extends StatelessWidget {
  const AfiliadosApp({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    return MultiProvider(
      providers: [
        Provider<ApiClient>(create: (_) => ApiClient()),
        ChangeNotifierProxyProvider<ApiClient, AuthService>(
          update: (_, api, previous) => previous ?? AuthService(api),
          create: (context) => AuthService(context.read<ApiClient>()),
        ),
        if (isMobile)
          Provider<PushService>(create: (_) => PushService.instance),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: buildGladyzTheme(),
        routes: {
          '/': (_) => const AuthGate(),
          '/login': (_) => const LoginPage(),
          '/home': (_) => const HomePage(),
          '/afiliados': (_) => const PermissionPage(
            permission: 'afiliados.ver',
            child: AfiliadosPage(),
          ),
          '/secciones': (_) => const PermissionPage(
            permission: 'secciones.ver',
            child: SeccionesPage(),
          ),
          '/actividades': (_) => const PermissionPage(
            permission: 'actividades.ver',
            child: ActividadesPage(),
          ),
          '/calendario': (_) => const PermissionPage(
            permission: 'actividades.ver',
            child: _CalendarShell(),
          ),
          '/mapa': (_) =>
              const PermissionPage(permission: 'mapa.ver', child: MapaPage()),
          '/reportes': (_) => const PermissionPage(
            permission: 'reportes.ver',
            child: ReportesPage(),
          ),
          '/avance': (_) => const PermissionPage(
            permission: 'avance.ver',
            child: AvancePage(),
          ),
          '/comunicados': (_) => const PermissionPage(
            permission: 'comunicados.ver',
            child: ComunicadosPage(),
          ),
          '/lonas': (_) =>
              const PermissionPage(permission: 'lonas.ver', child: LonasPage()),
          '/lonas/nueva': (_) => const PermissionPage(
            permission: 'lonas.crear',
            child: LonaCapturePage(),
          ),
          '/admin': (_) => const AdminPage(),
          '/admin/usuarios': (_) => const PermissionPage(
            permission: 'usuarios.ver',
            child: UsuariosPage(),
          ),
          '/admin/roles': (_) =>
              const PermissionPage(permission: 'roles.ver', child: RolesPage()),
          '/admin/permisos': (_) => const PermissionPage(
            permission: 'permisos.ver',
            child: RolePermissionsPage(),
          ),
          '/admin/comunicados': (_) => const PermissionPage(
            permission: 'comunicados.ver',
            child: ComunicadosAdminPage(),
          ),
          '/admin/configuracion': (_) => const PermissionPage(
            permission: 'settings.ver',
            child: AppSettingsPage(),
          ),
        },
      ),
    );
  }
}

class _CalendarShell extends StatelessWidget {
  const _CalendarShell();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Calendario'),
      actions: [
        IconButton(
          tooltip: 'Administrar actividades',
          onPressed: () => Navigator.pushNamed(context, '/actividades'),
          icon: const Icon(Icons.view_list_rounded),
        ),
      ],
    ),
    body: const CalendarPage(),
  );
}
