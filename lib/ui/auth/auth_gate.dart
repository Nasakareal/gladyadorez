import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand_theme.dart';
import '../../services/auth_service.dart';
import '../home/home_page.dart';
import 'login_page.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<bool> _restore;

  @override
  void initState() {
    super.initState();
    _restore = context.read<AuthService>().restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _restore,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: GladyzBackdrop(
              child: Center(
                child: CircularProgressIndicator(color: GladyzColors.granate),
              ),
            ),
          );
        }
        return context.watch<AuthService>().isAuthenticated
            ? const HomePage()
            : const LoginPage();
      },
    );
  }
}

class PermissionPage extends StatelessWidget {
  const PermissionPage({
    super.key,
    required this.permission,
    required this.child,
  });

  final String permission;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (context.watch<AuthService>().can(permission)) return child;
    return const Scaffold(
      body: Center(child: Text('Esta opción no está disponible.')),
    );
  }
}
