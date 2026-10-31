import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../config.dart';
import '../../core/theme.dart';
import '../../models/settings.dart';
import '../../services/location_service.dart';
import '../../widgets/ui.dart';
import '../onboarding/profile_screen.dart';

/// Perfil, voz, avisos, tamaño de letra y privacidad.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _orsKey;
  bool _showKey = false;

  @override
  void initState() {
    super.initState();
    _orsKey = TextEditingController(text: AppScope.read(context).settings.orsApiKey);
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => AppScope.read(context).voice.announce('Ajustes'));
  }

  @override
  void dispose() {
    _orsKey.dispose();
    super.dispose();
  }

  Future<void> _saveKey(AppState app) async {
    await app.updateSettings(app.settings.copyWith(orsApiKey: _orsKey.text.trim()));
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    await app.voice.speak(app.hasRoutingKey
        ? 'Clave guardada. Ya puedes pedir rutas.'
        : 'Clave borrada.');
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final s = app.settings;
    final rl = context.rl;
    final muted = TextStyle(fontSize: 14, color: rl.text2);
    TextStyle title() =>
        TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: rl.text);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _Section(
              title: 'Perfil',
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: rl.primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.person_outline, color: rl.primary),
                  ),
                  title: Text(app.profile.label, style: title()),
                  subtitle: Text(app.profile.description, style: muted),
                  trailing: Icon(Icons.chevron_right, color: rl.text2),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const ProfileScreen())),
                ),
              ],
            ),
            _Section(
              title: 'Apariencia',
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Text('Tema', style: title()),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                  child: Segmented<ThemePreference>(
                    values: ThemePreference.values,
                    selected: s.theme,
                    labelOf: (t) => t.label,
                    semanticPrefix: 'Tema ',
                    onChanged: (t) => app.updateSettings(s.copyWith(theme: t)),
                  ),
                ),
                const Divider(indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Text('Tamaño de letra', style: title()),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text('Así se verá el texto de la app.', style: muted),
                ),
                Slider(
                  value: s.textScale,
                  min: 1.0,
                  max: 2.0,
                  divisions: 5,
                  semanticFormatterCallback: (v) =>
                      '${(v * 100).round()} por ciento',
                  onChanged: (v) => app.updateSettings(s.copyWith(textScale: v)),
                ),
              ],
            ),
            _Section(
              title: 'Voz y avisos',
              children: [
                SwitchListTile(
                  title: Text('Guía por voz', style: title()),
                  subtitle: Text('Anunciar cada pantalla y acción', style: muted),
                  value: s.voiceGuidance,
                  onChanged: (v) =>
                      app.updateSettings(s.copyWith(voiceGuidance: v)),
                ),
                const Divider(indent: 16, endIndent: 16),
                SwitchListTile(
                  title: Text('Avisar peligros cercanos', style: title()),
                  subtitle: Text(
                      'Voz y vibración a ${AppConfig.hazardAlertMeters.round()} m '
                      'de un peligro reportado',
                      style: muted),
                  value: s.hazardAlerts,
                  onChanged: (v) =>
                      app.updateSettings(s.copyWith(hazardAlerts: v)),
                ),
                if (LocationService.supportsBackground) ...[
                  const Divider(indent: 16, endIndent: 16),
                  SwitchListTile(
                    title: Text('Avisar con la pantalla apagada', style: title()),
                    subtitle: Text(
                        'Sigue usando tu ubicación con el teléfono bloqueado o '
                        'en la bolsa. Muestra una notificación fija y usa más '
                        'batería.',
                        style: muted),
                    value: s.backgroundLocation,
                    onChanged: (v) async {
                      await app.updateSettings(s.copyWith(backgroundLocation: v));
                      await app.voice.announce(v
                          ? 'Te avisaré de peligros aunque bloquees el teléfono.'
                          : 'Solo te avisaré con la app abierta.');
                    },
                  ),
                ],
                const Divider(indent: 16, endIndent: 16),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Text('Velocidad de la voz', style: title()),
                ),
                Slider(
                  value: s.speechRate,
                  min: 0.3,
                  max: 0.7,
                  divisions: 4,
                  semanticFormatterCallback: (v) =>
                      v < 0.45 ? 'lenta' : (v > 0.55 ? 'rápida' : 'normal'),
                  onChanged: (v) => app.updateSettings(s.copyWith(speechRate: v)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: () =>
                          app.voice.speak('Así sueno con esta velocidad.'),
                      icon: const Icon(Icons.record_voice_over_outlined, size: 20),
                      label: const Text('Probar voz'),
                    ),
                  ),
                ),
              ],
            ),
            _Section(
              title: 'Rutas',
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                              app.hasRoutingKey
                                  ? Icons.check_circle
                                  : Icons.info_outline,
                              color: app.hasRoutingKey
                                  ? AppTheme.accessYes
                                  : rl.text2),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              app.hasRoutingKey
                                  ? 'Las rutas están activas.'
                                  : 'Para calcular rutas hace falta una clave '
                                      'gratuita de openrouteservice.org. Se '
                                      'guarda solo en este dispositivo.',
                              style: TextStyle(fontSize: 15, color: rl.text),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _orsKey,
                        obscureText: !_showKey,
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: 'Clave de openrouteservice',
                          suffixIcon: IconButton(
                            tooltip: _showKey ? 'Ocultar clave' : 'Mostrar clave',
                            icon: Icon(_showKey
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                            onPressed: () => setState(() => _showKey = !_showKey),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => _saveKey(app),
                        child: const Text('Guardar clave'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            _Section(
              title: 'Datos del mapa',
              children: [
                ListTile(
                  title: Text('Actualizar lugares', style: title()),
                  subtitle: Text(
                      'Descarga de nuevo los lugares de donde estás. Vienen de '
                      'OpenStreetMap y se guardan en el teléfono por '
                      '${AppConfig.placesCacheTtl.inDays} días.',
                      style: muted),
                  trailing: app.loadingPlaces
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5))
                      : Icon(Icons.refresh, color: rl.primary),
                  onTap: app.loadingPlaces
                      ? null
                      : () async {
                          await app.loadPlaces(app.me ?? AppConfig.pilotCenter,
                              force: true);
                          await app.voice
                              .speak(app.placesError ?? 'Lugares actualizados.');
                        },
                ),
              ],
            ),
            _Section(
              title: 'Privacidad',
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Tu ubicación se usa en el teléfono para mostrar qué hay '
                    'cerca. En este prototipo los reportes se guardan solo en '
                    'tu teléfono. Cuando se compartan, se enviará la ubicación '
                    'del peligro, nunca tu recorrido.',
                    style: TextStyle(fontSize: 15, height: 1.4, color: rl.text),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Grupo de ajustes con título y tarjeta.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rl = context.rl;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Semantics(
              header: true,
              child: Text(title.toUpperCase(),
                  style: TextStyle(
                      fontSize: 13,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w700,
                      color: rl.text2)),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
