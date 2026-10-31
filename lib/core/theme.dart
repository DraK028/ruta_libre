import 'package:flutter/material.dart';

/// Colores del diseño. Los de estado (accesible, peligro…) son iguales en
/// claro y oscuro: van sobre un aro blanco, así que contrastan en ambos.
class AppTheme {
  static const fontFamily = 'Atkinson Hyperlegible';

  // Estado de accesibilidad: cada uno va siempre con ícono y forma propios.
  static const accessYes = Color(0xFF157F3D);
  static const accessLimited = Color(0xFFA16207);
  static const accessNo = Color(0xFFB42318);
  static const accessUnknown = Color(0xFF5B6773);
  static const hazard = Color(0xFFC2410C);
  static const userDot = Color(0xFF1D4ED8);

  /// Altura mínima de cualquier control tocable.
  static const minTouch = 48.0;

  static ThemeData light() => _build(RLColors.light, Brightness.light);
  static ThemeData dark() => _build(RLColors.dark, Brightness.dark);

  static ThemeData _build(RLColors c, Brightness b) {
    final scheme = ColorScheme(
      brightness: b,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primarySoft,
      onPrimaryContainer: c.primary,
      secondary: c.primary,
      onSecondary: c.onPrimary,
      error: accessNo,
      onError: Colors.white,
      surface: c.surface,
      onSurface: c.text,
      onSurfaceVariant: c.text2,
      surfaceContainerHighest: c.surface2,
      outline: c.border,
      outlineVariant: c.border,
    );

    TextStyle t(double size, [FontWeight w = FontWeight.w400]) => TextStyle(
        fontFamily: fontFamily, fontSize: size, fontWeight: w, color: c.text, height: 1.3);

    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: c.background,
      extensions: [c],
      textTheme: TextTheme(
        displaySmall: t(32, FontWeight.w700),
        headlineMedium: t(28, FontWeight.w700),
        headlineSmall: t(22, FontWeight.w700),
        titleLarge: t(19, FontWeight.w700),
        titleMedium: t(17, FontWeight.w700),
        bodyLarge: t(17),
        bodyMedium: t(15),
        labelLarge: t(17, FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.text,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: t(22, FontWeight.w700),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.primary,
          foregroundColor: c.onPrimary,
          elevation: 0,
          minimumSize: const Size.fromHeight(56),
          textStyle: t(18, FontWeight.w700),
          shape: shape,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.primarySoft,
          foregroundColor: c.primary,
          minimumSize: const Size(minTouch, minTouch),
          textStyle: t(16, FontWeight.w700),
          shape: const StadiumBorder(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.text,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: c.border),
          textStyle: t(16, FontWeight.w700),
          shape: shape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: c.primary,
          minimumSize: const Size(minTouch, minTouch),
          textStyle: t(16, FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        labelStyle: t(16).copyWith(color: c.text2),
        hintStyle: t(16).copyWith(color: c.text2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c.primary, width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: c.border),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.border, space: 1, thickness: 1),
      listTileTheme: ListTileThemeData(
        textColor: c.text,
        iconColor: c.text,
        minVerticalPadding: 12,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? c.onPrimary : c.text2),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? c.primary : c.surface2),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.primary,
        thumbColor: c.primary,
        inactiveTrackColor: c.surface2,
        trackHeight: 6,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        showDragHandle: true,
        dragHandleColor: c.handle,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.text,
        contentTextStyle: t(16).copyWith(color: c.background),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),
    );
  }
}

/// Tokens de color de la app. Se leen con `context.rl`.
@immutable
class RLColors extends ThemeExtension<RLColors> {
  const RLColors({
    required this.background,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.handle,
    required this.text,
    required this.text2,
    required this.primary,
    required this.primarySoft,
    required this.onPrimary,
    required this.okSoft,
    required this.okText,
    required this.hazardSoft,
    required this.hazardText,
  });

  final Color background;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color handle;
  final Color text;

  /// Texto secundario: cumple 4.5:1 sobre `surface`.
  final Color text2;
  final Color primary;
  final Color primarySoft;
  final Color onPrimary;
  final Color okSoft;
  final Color okText;
  final Color hazardSoft;
  final Color hazardText;

  static const light = RLColors(
    background: Color(0xFFF4F6F8),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEEF1F4),
    border: Color(0xFFD5DBE1),
    handle: Color(0xFFC3CAD2),
    text: Color(0xFF10202E),
    text2: Color(0xFF4B5966),
    primary: Color(0xFF1D4ED8),
    primarySoft: Color(0xFFE6EDFC),
    onPrimary: Color(0xFFFFFFFF),
    okSoft: Color(0xFFE7F4EC),
    okText: Color(0xFF0F5B2C),
    hazardSoft: Color(0xFFFDEEE6),
    hazardText: Color(0xFF8A2C07),
  );

  static const dark = RLColors(
    background: Color(0xFF0F151B),
    surface: Color(0xFF161D25),
    surface2: Color(0xFF1F2832),
    border: Color(0xFF2C3742),
    handle: Color(0xFF3A4652),
    text: Color(0xFFE6EDF3),
    text2: Color(0xFFA9B6C2),
    primary: Color(0xFF8AB4FF),
    primarySoft: Color(0xFF1E2D4A),
    onPrimary: Color(0xFF0B1B33),
    okSoft: Color(0xFF12301F),
    okText: Color(0xFF8EE0AE),
    hazardSoft: Color(0xFF3A1D10),
    hazardText: Color(0xFFFFB48F),
  );

  @override
  RLColors copyWith() => this;

  @override
  RLColors lerp(ThemeExtension<RLColors>? other, double t) =>
      other is RLColors && t >= 0.5 ? other : this;
}

extension RLColorsX on BuildContext {
  RLColors get rl => Theme.of(this).extension<RLColors>() ?? RLColors.light;
}
