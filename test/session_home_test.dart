import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sistema_afiliados_app/services/api_client.dart';
import 'package:sistema_afiliados_app/services/auth_service.dart';
import 'package:sistema_afiliados_app/ui/home/home_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    dotenv.loadFromString(envString: 'API_BASE_URL=https://example.test/api');
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'home card lays out inside an unbounded wrap without assertions',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Wrap(
              children: const [
                SizedBox(
                  width: 170,
                  child: HomeModuleCard(
                    title: 'Afiliados',
                    subtitle: 'Registro, consulta y seguimiento',
                    icon: Icons.people,
                    route: '/afiliados',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Afiliados'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('cached session survives a remote 401 during app startup', () async {
    final first = await _loggedInService();
    expect(first.isAuthenticated, isTrue);

    final restartedApi = ApiClient();
    restartedApi.dio.interceptors.insert(
      0,
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException(
            requestOptions: options,
            response: Response(requestOptions: options, statusCode: 401),
          ),
        ),
      ),
    );
    final restarted = AuthService(restartedApi);

    expect(await restarted.restoreSession(), isTrue);
    expect(restarted.user?.name, 'Gladyz');
    expect(restarted.can('afiliados.ver'), isTrue);
  });
}

Future<AuthService> _loggedInService() async {
  final api = ApiClient();
  api.dio.interceptors.insert(
    0,
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'token': 'token-de-prueba',
            'user': {
              'id': 1,
              'name': 'Gladyz',
              'email': 'gladyz@example.test',
              'roles': ['Consulta'],
              'permissions': ['afiliados.ver'],
            },
          },
        ),
      ),
    ),
  );
  final auth = AuthService(api);
  expect(await auth.login('gladyz@example.test', 'password'), isTrue);
  return auth;
}
