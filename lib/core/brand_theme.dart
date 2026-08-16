import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class GladyzColors {
  static const granate = Color(0xFF7A0019);
  static const granateOscuro = Color(0xFF4A000F);
  static const dorado = Color(0xFFF2C14E);
  static const humo = Color(0xFFF4F2F4);
  static const tinta = Color(0xFF24171B);
}

ThemeData buildGladyzTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: GladyzColors.granate,
          brightness: Brightness.light,
        ).copyWith(
          primary: GladyzColors.granate,
          secondary: GladyzColors.dorado,
          surface: Colors.white.withValues(alpha: .86),
        ),
  );

  final radius = BorderRadius.circular(20);
  return base.copyWith(
    scaffoldBackgroundColor: GladyzColors.humo,
    textTheme: GoogleFonts.montserratTextTheme(
      base.textTheme,
    ).apply(bodyColor: GladyzColors.tinta, displayColor: GladyzColors.tinta),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      backgroundColor: GladyzColors.granate.withValues(alpha: .92),
      foregroundColor: Colors.white,
      titleTextStyle: GoogleFonts.montserrat(
        fontWeight: FontWeight.w800,
        fontSize: 18,
        color: Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white.withValues(alpha: .72),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: Colors.white.withValues(alpha: .82)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: .74),
      border: OutlineInputBorder(borderRadius: radius),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(
          color: GladyzColors.granate.withValues(alpha: .12),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: GladyzColors.granate, width: 1.4),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: GladyzColors.granate,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: GladyzColors.granate,
      foregroundColor: Colors.white,
    ),
  );
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.tint = Colors.white,
    this.opacity = .64,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;
  final Color tint;
  final double opacity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint.withValues(alpha: opacity),
            borderRadius: borderRadius,
            border: Border.all(color: Colors.white.withValues(alpha: .72)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x16000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: borderRadius,
                onTap: onTap,
                child: content,
              ),
            ),
    );
  }
}

class GladyzBackdrop extends StatelessWidget {
  const GladyzBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF9F4F5), Color(0xFFF1E7EA), Color(0xFFFFF8E8)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -110,
            right: -80,
            child: _Orb(color: GladyzColors.dorado, size: 250),
          ),
          Positioned(
            bottom: -130,
            left: -100,
            child: _Orb(color: GladyzColors.granate, size: 300),
          ),
          child,
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => ImageFiltered(
    imageFilter: ImageFilter.blur(sigmaX: 36, sigmaY: 36),
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: .18),
      ),
    ),
  );
}
