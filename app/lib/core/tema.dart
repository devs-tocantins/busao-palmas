import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cores e medidas de docs/DESIGN.md.
abstract final class Tokens {
  static const amarelo = Color(0xFFFFD100);
  static const azul = Color(0xFF0B5FA5);
  static const azulEscuro = Color(0xFF6AA9E8);
  static const aoVivo = Color(0xFF0E7A37);
  static const aoVivoEscuro = Color(0xFF4CC27A);
  static const atraso = Color(0xFF9A4A00);
  static const erro = Color(0xFFC62828);

  static const raioCartao = 12.0;
  static const raioPainel = 20.0;
  static const margem = 16.0;
}

abstract final class Tema {
  static ThemeData claro() => _montar(
    ColorScheme.light(
      primary: Colors.black,
      onPrimary: Colors.white,
      secondary: Tokens.azul,
      surface: Colors.white,
      onSurface: const Color(0xFF141414),
      surfaceContainerHighest: const Color(0xFFF6F6F6),
      outline: const Color(0xFFE2E2E2),
      onSurfaceVariant: const Color(0xFF5E5E5E),
      error: Tokens.erro,
    ),
  );

  static ThemeData escuro() => _montar(
    ColorScheme.dark(
      primary: Colors.white,
      onPrimary: Colors.black,
      secondary: Tokens.azulEscuro,
      surface: Colors.black,
      onSurface: Colors.white,
      surfaceContainerHighest: const Color(0xFF1A1A1A),
      outline: const Color(0xFF333333),
      onSurfaceVariant: const Color(0xFFB5B5B5),
      error: const Color(0xFFEF9A9A),
    ),
  );

  static ThemeData _montar(ColorScheme cs) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      brightness: cs.brightness,
    );
    final texto = GoogleFonts.interTextTheme(base.textTheme)
        .apply(bodyColor: cs.onSurface, displayColor: cs.onSurface);
    return base.copyWith(
      scaffoldBackgroundColor: cs.surface,
      textTheme: texto,
      dividerColor: cs.outline,
      appBarTheme: AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: texto.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: cs.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tokens.raioCartao),
          side: BorderSide(color: cs.outline),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cs.surface,
        indicatorColor: Tokens.amarelo,
        iconTheme: WidgetStateProperty.resolveWith(
          (e) => IconThemeData(
            color: e.contains(WidgetState.selected)
                ? Colors.black
                : cs.onSurfaceVariant,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
          textStyle: texto.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Tokens.raioCartao),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
