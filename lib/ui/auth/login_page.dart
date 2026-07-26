import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool loading = false;
  String? error;
  bool remember = false;

  // Colores de marca
  static const granate = Color(0xFF7A0019);
  static const granateOsc = Color(0xFF5C0013);
  static const dorado = Color(0xFFF2C14E);

  Future<void> _doLogin() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final auth = context.read<AuthService>();
      final ok = await auth.login(emailCtrl.text.trim(), passCtrl.text);
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pushReplacementNamed(auth.landingRoute);
      } else {
        setState(() => error = 'Credenciales inválidas');
      }
    } catch (e) {
      setState(() => error = 'Error: $e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 992;
    final cardMaxWidth = isWide ? 520.0 : 560.0;

    return Scaffold(
      body: Stack(
        children: [
          // Fondo con imagen + blur
          Positioned.fill(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset('assets/images/portada2.jpeg', fit: BoxFit.cover),
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: const SizedBox.expand(),
                ),
                // Overlay degradado (granate + oscurecido)
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.fromARGB(50, 0, 0, 0),
                        Color.fromARGB(90, 0, 0, 0),
                      ],
                    ),
                  ),
                ),
                // Radial granate suave
                Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.6, -0.9),
                      radius: 1.2,
                      colors: [
                        granate.withValues(alpha: .28),
                        granate.withValues(alpha: .45),
                        granateOsc.withValues(alpha: .62),
                      ],
                      stops: const [0.10, 0.55, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Contenido
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Marca
                    GestureDetector(
                      onTap: () {
                        // si quieres: Navigator.pushNamed(context, '/welcome');
                      },
                      child: Column(
                        children: [
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'GLADY',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: .6,
                                    color: Colors.white,
                                  ),
                                ),
                                TextSpan(
                                  text: '•',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: dorado,
                                  ),
                                ),
                                TextSpan(
                                  text: 'ADOREZ',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: .6,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Acceso para el equipo',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: .85),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Tarjeta glass
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: cardMaxWidth),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 26,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .28),
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color.fromARGB(77, 0, 0, 0),
                                  blurRadius: 30,
                                  offset: Offset(0, 18),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.login_rounded,
                                      color: granate,
                                      size: 26,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Iniciar sesión',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                if (error != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: .85,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.black.withValues(
                                          alpha: .08,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      error!,
                                      style: GoogleFonts.montserrat(
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                // Email
                                Text(
                                  'Correo electrónico',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: emailCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    hintText: 'tucorreo@dominio.com',
                                    filled: true,
                                    fillColor: Colors.white.withValues(
                                      alpha: .88,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: .45,
                                        ),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: Colors.white.withValues(
                                          alpha: .45,
                                        ),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: granate,
                                        width: 1.2,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),

                                // Password
                                Text(
                                  'Contraseña',
                                  style: GoogleFonts.montserrat(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                _PasswordField(
                                  controller: passCtrl,
                                  onSubmitted: (_) =>
                                      loading ? null : _doLogin(),
                                ),
                                const SizedBox(height: 10),

                                // Remember + forgot
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Checkbox(
                                          value: remember,
                                          activeColor: granate,
                                          onChanged: (v) => setState(
                                            () => remember = v ?? false,
                                          ),
                                        ),
                                        Text(
                                          'Recordarme',
                                          style: GoogleFonts.montserrat(
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    InkWell(
                                      onTap: () {
                                        // Navigator.of(context).pushNamed('/forgot');
                                      },
                                      child: Text(
                                        '¿Olvidaste tu contraseña?',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12.5,
                                          color: Colors.white.withValues(
                                            alpha: .95,
                                          ),
                                          decoration: TextDecoration.underline,
                                          decorationColor: Colors.white
                                              .withValues(alpha: .95),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                // Botón
                                SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: loading ? null : _doLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: granate,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      textStyle: GoogleFonts.montserrat(
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: .2,
                                      ),
                                    ),
                                    child: loading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.6,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.lock_open_rounded,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Entrar',
                                                style: GoogleFonts.montserrat(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // Footer pequeño dentro de la tarjeta (links)
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        // Navigator.pushNamed(context, '/welcome');
                                      },
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.chevron_left_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            'Volver al inicio',
                                            style: GoogleFonts.montserrat(
                                              color: Colors.white.withValues(
                                                alpha: .95,
                                              ),
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        // Navigator.pushNamed(context, '/register');
                                      },
                                      child: Text(
                                        'Crear cuenta',
                                        style: GoogleFonts.montserrat(
                                          color: Colors.white.withValues(
                                            alpha: .95,
                                          ),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Copyright
                    Text(
                      '© ${DateTime.now().year} GLADYADOREZ · Acceso restringido',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        color: Colors.white.withValues(alpha: .75),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;
  const _PasswordField({required this.controller, this.onSubmitted});
  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: obscure,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        hintText: '••••••••',
        filled: true,
        fillColor: Colors.white.withValues(alpha: .88),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: .45)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: .45)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: _LoginPageState.granate,
            width: 1.2,
          ),
        ),
        suffixIcon: IconButton(
          onPressed: () => setState(() => obscure = !obscure),
          icon: Icon(
            obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
          ),
        ),
      ),
    );
  }
}
