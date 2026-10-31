import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_state.dart';
import 'core/theme.dart';
import 'features/map/map_screen.dart';
import 'features/onboarding/profile_screen.dart';
import 'models/settings.dart';

class RutaLibreApp extends StatefulWidget {
  const RutaLibreApp({super.key, required this.state});

  final AppState state;

  @override
  State<RutaLibreApp> createState() => _RutaLibreAppState();
}

class _RutaLibreAppState extends State<RutaLibreApp> {
  late final bool _needsProfile = widget.state.settings.profile == null;
  late ThemePreference _theme = widget.state.settings.theme;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onState);
  }

  /// Solo se reconstruye la app entera si cambia el tema.
  void _onState() {
    final next = widget.state.settings.theme;
    if (next != _theme) setState(() => _theme = next);
  }

  @override
  void dispose() {
    widget.state.removeListener(_onState);
    widget.state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: widget.state,
      child: MaterialApp(
        title: 'Ruta Libre',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: switch (_theme) {
          ThemePreference.system => ThemeMode.system,
          ThemePreference.light => ThemeMode.light,
          ThemePreference.dark => ThemeMode.dark,
        },
        locale: const Locale('es', 'MX'),
        supportedLocales: const [Locale('es', 'MX'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) {
          // Nunca más chico que la letra del sistema; tope para no desbordar.
          final media = MediaQuery.of(context);
          final system = media.textScaler.scale(100) / 100;
          final user = AppScope.of(context).settings.textScale;
          final scale = math.min(math.max(system, user), 2.0);
          return MediaQuery(
            data: media.copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          );
        },
        home: _needsProfile
            ? const ProfileScreen(firstTime: true)
            : const MapScreen(),
      ),
    );
  }
}
