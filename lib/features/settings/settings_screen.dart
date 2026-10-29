import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../config.dart';
import '../../core/theme.dart';
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
    final text = Theme.of(context).textTheme;
    final muted = text.bodyMedium?.copyWith(color: AppTheme.textMuted);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Perfil', style: text.headlineMedium),
            const SizedBox(height: 8),
            Text(app.profile.label, style: text.titleLarge),
            Text(app.profile.description, style: muted),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const ProfileScreen())),
              child: const Text('Cambiar perfil'),
            ),
            const Divider(height: 40, color: AppTheme.textMuted),
            Text('Voz y avisos', style: text.headlineMedium),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Guía por voz', style: text.titleLarge),
              subtitle: Text('Anunciar cada pantalla y acción', style: muted),
              value: s.voiceGuidance,
              onChanged: (v) => app.updateSettings(s.copyWith(voiceGuidance: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Avisar peligros cercanos', style: text.titleLarge),
              subtitle: Text(
                  'Voz y vibración a ${AppConfig.hazardAlertMeters.round()} m '
                  'de un peligro reportado',
                  style: muted),
              value: s.hazardAlerts,
              onChanged: (v) => app.updateSettings(s.copyWith(hazardAlerts: v)),
            ),
            const SizedBox(height: 8),
            Text('Velocidad de la voz', style: text.titleLarge),
            Slider(
              value: s.speechRate,
              min: 0.3,
              max: 0.7,
              divisions: 4,
              semanticFormatterCallback: (v) =>
                  v < 0.45 ? 'lenta' : (v > 0.55 ? 'rápida' : 'normal'),
              onChanged: (v) => app.updateSettings(s.copyWith(speechRate: v)),
            ),
            OutlinedButton.icon(
              onPressed: () => app.voice.speak('Así sueno con esta velocidad.'),
              icon: const Icon(Icons.record_voice_over, size: 30),
              label: const Text('Probar voz'),
            ),
            const Divider(height: 40, color: AppTheme.textMuted),
            Text('Tamaño de letra', style: text.headlineMedium),
            Text('Ejemplo de texto', style: text.bodyLarge),
            Slider(
              value: s.textScale,
              min: 1.0,
              max: 2.0,
              divisions: 5,
              semanticFormatterCallback: (v) => '${(v * 100).round()} por ciento',
              onChanged: (v) => app.updateSettings(s.copyWith(textScale: v)),
            ),
            const Divider(height: 40, color: AppTheme.textMuted),
            Text('Rutas', style: text.headlineMedium),
            const SizedBox(height: 8),
            Text(
              app.hasRoutingKey
                  ? 'Las rutas están activas.'
                  : 'Para calcular rutas hace falta una clave gratuita de '
                      'openrouteservice.org. Se guarda solo en este dispositivo.',
              style: text.bodyLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _orsKey,
              obscureText: !_showKey,
              autocorrect: false,
              enableSuggestions: false,
              style: text.bodyLarge,
              decoration: InputDecoration(
                labelText: 'Clave de openrouteservice',
                suffixIcon: IconButton(
                  iconSize: 28,
                  tooltip: _showKey ? 'Ocultar clave' : 'Mostrar clave',
                  icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showKey = !_showKey),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _saveKey(app),
              child: const Text('Guardar clave'),
            ),
            const Divider(height: 40, color: AppTheme.textMuted),
            Text('Datos del mapa', style: text.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Los lugares vienen de OpenStreetMap y se guardan en el teléfono '
              'por ${AppConfig.placesCacheTtl.inDays} días.',
              style: text.bodyLarge,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: app.loadingPlaces
                  ? null
                  : () async {
                      await app.loadPlaces(AppConfig.pilotCenter, force: true);
                      await app.voice.speak(app.placesError ??
                          'Lugares actualizados.');
                    },
              icon: const Icon(Icons.refresh, size: 30),
              label: Text(app.loadingPlaces ? 'Actualizando…' : 'Actualizar lugares'),
            ),
            const Divider(height: 40, color: AppTheme.textMuted),
            Text('Privacidad', style: text.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Tu ubicación se usa en el teléfono para mostrar qué hay cerca. '
              'En este prototipo los reportes se guardan solo en tu teléfono. '
              'Cuando se compartan, se enviará la ubicación del peligro, '
              'nunca tu recorrido.',
              style: text.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
