import 'package:flutter/material.dart';

/// Tema de alto contraste: fondo negro, texto blanco y acciones en amarillo.
///
/// Amarillo sobre negro supera por mucho el contraste mínimo de 7:1 (WCAG AAA)
/// y es una combinación habitual en apps para baja visión.
class AppTheme {
  static const background = Color(0xFF000000);
  static const surface = Color(0xFF121212);
  static const accent = Color(0xFFFFD400);
  static const onAccent = Color(0xFF000000);
  static const text = Color(0xFFFFFFFF);
  static const textMuted = Color(0xFFD6D6D6);
  static const danger = Color(0xFFFF6B5B);
  static const success = Color(0xFF7CE38B);

  // Colores de accesibilidad en el mapa. Cada uno va con un ícono distinto
  // para no depender solo del color (daltonismo).
  static const accessYes = Color(0xFF1FA34A);
  static const accessLimited = Color(0xFFF2A900);
  static const accessNo = Color(0xFFD7263D);
  static const accessUnknown = Color(0xFF8A8A8A);
  static const hazard = Color(0xFFFF3B30);

  /// Altura mínima de cualquier botón (la guía de Material pide 48).
  static const minTouch = 72.0;

  static ThemeData build() {
    const scheme = ColorScheme.dark(
      primary: accent,
      onPrimary: onAccent,
      secondary: accent,
      onSecondary: onAccent,
      surface: surface,
      onSurface: text,
      error: danger,
      onError: onAccent,
    );

    const base = TextStyle(color: text, height: 1.3);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      visualDensity: VisualDensity.comfortable,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textTheme: TextTheme(
        displaySmall: base.copyWith(fontSize: 34, fontWeight: FontWeight.w700),
        headlineMedium: base.copyWith(fontSize: 28, fontWeight: FontWeight.w700),
        titleLarge: base.copyWith(fontSize: 24, fontWeight: FontWeight.w700),
        bodyLarge: base.copyWith(fontSize: 22),
        bodyMedium: base.copyWith(fontSize: 20),
        labelLarge: base.copyWith(fontSize: 22, fontWeight: FontWeight.w700),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        centerTitle: false,
        toolbarHeight: 72,
        titleTextStyle:
            TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: text),
        iconTheme: IconThemeData(size: 32),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          minimumSize: const Size.fromHeight(minTouch),
          textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          minimumSize: const Size.fromHeight(minTouch),
          side: const BorderSide(color: text, width: 2),
          textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: TextStyle(fontSize: 20, color: textMuted),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        border: OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: textMuted, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: accent, width: 3),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: text,
        iconColor: accent,
        minVerticalPadding: 16,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: accent,
        thumbColor: accent,
        trackHeight: 8,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? onAccent : text,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? accent : surface,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: accent,
        contentTextStyle: TextStyle(fontSize: 20, color: onAccent),
      ),
    );
  }
}
