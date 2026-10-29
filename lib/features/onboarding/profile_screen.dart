import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_state.dart';
import '../../core/theme.dart';
import '../../models/settings.dart';
import '../map/map_screen.dart';

/// Elección del perfil de movilidad. Se muestra al abrir la app por primera
/// vez y desde Ajustes.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.firstTime = false});

  final bool firstTime;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = AppScope.read(context);
      // La bienvenida se dice siempre: quien no ve aún no ha elegido nada.
      app.voice.speak(widget.firstTime
          ? 'Bienvenido a Ruta Libre. Elige cómo te mueves para adaptar el '
              'mapa y las rutas. Opciones: silla de ruedas, bastón o andadera, '
              'baja visión o ceguera.'
          : 'Elige tu perfil.');
    });
  }

  Future<void> _choose(MobilityProfile p) async {
    final app = AppScope.read(context);
    await HapticFeedback.mediumImpact();
    if (widget.firstTime) {
      await app.chooseProfile(p);
    } else {
      await app.updateSettings(app.settings.copyWith(profile: p));
    }
    await app.voice.speak('Perfil: ${p.label}.');
    if (!mounted) return;
    if (widget.firstTime) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const MapScreen()),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final current = AppScope.of(context).settings.profile;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.firstTime,
        title: Text(widget.firstTime ? 'Bienvenido' : 'Tu perfil'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('¿Cómo te mueves?', style: text.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Ruta Libre adapta el mapa, las rutas y los avisos a tu perfil. '
              'Puedes cambiarlo después en Ajustes.',
              style: text.bodyLarge?.copyWith(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            for (final p in MobilityProfile.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ProfileOption(
                  profile: p,
                  selected: p == current,
                  onTap: () => _choose(p),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  const _ProfileOption({
    required this.profile,
    required this.selected,
    required this.onTap,
  });

  final MobilityProfile profile;
  final bool selected;
  final VoidCallback onTap;

  IconData get _icon => switch (profile) {
        MobilityProfile.wheelchair => Icons.accessible,
        MobilityProfile.mobilityAid => Icons.elderly,
        MobilityProfile.lowVision => Icons.visibility,
        MobilityProfile.blind => Icons.blind,
      };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '${profile.label}. ${profile.description}',
      excludeSemantics: true,
      child: Material(
        color: selected ? AppTheme.accent : AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 96),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? AppTheme.accent : AppTheme.textMuted,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(_icon,
                    size: 48,
                    color: selected ? AppTheme.onAccent : AppTheme.accent),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.label,
                          style: text.titleLarge?.copyWith(
                              color: selected
                                  ? AppTheme.onAccent
                                  : AppTheme.text)),
                      const SizedBox(height: 4),
                      Text(profile.description,
                          style: text.bodyMedium?.copyWith(
                              color: selected
                                  ? AppTheme.onAccent
                                  : AppTheme.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
