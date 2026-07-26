import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/constants.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/push_service.dart';
import 'ui/auth/login_page.dart';
import 'ui/home/home_page.dart';
import 'ui/comunicados/comunicados_page.dart';
import 'ui/lonas/lona_capture_page.dart';
import 'ui/lonas/lonas_page.dart';

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

  // Paleta “granate/dorado”
  static const _granate = Color(0xFF7A0019);
  static const _granateOsc = Color(0xFF5C0013);

  @override
  Widget build(BuildContext context) {
    final bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _granate,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    );

    final themed = base.copyWith(
      textTheme: GoogleFonts.montserratTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: _granate,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.montserrat(
          fontWeight: FontWeight.w800,
          fontSize: 18,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _granate,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      colorScheme: base.colorScheme.copyWith(
        primary: _granate,
        secondary: _granateOsc,
      ),
    );

    return MultiProvider(
      providers: [
        Provider<ApiClient>(create: (_) => ApiClient()),
        ProxyProvider<ApiClient, AuthService>(
          update: (_, api, __) => AuthService(api),
          create: (_) => AuthService(ApiClient()),
        ),
        if (isMobile)
          Provider<PushService>(create: (_) => PushService.instance),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: themed,
        routes: {
          '/': (_) => const LoginPage(),
          '/home': (_) => const HomePage(),
          '/comunicados': (_) => const ComunicadosPage(),
          '/lonas': (_) => const LonasPage(),
          '/lonas/nueva': (_) => const LonaCapturePage(),
        },
      ),
    );
  }
}
