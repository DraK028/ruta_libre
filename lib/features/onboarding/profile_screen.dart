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
  MobilityProfile? _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = AppScope.read(context).settings.profile;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = AppScope.read(context);
      // La bienvenida se dice siempre: quien no ve aún no ha elegido nada.
      app.voice.speak(widget.firstTime
          ? 'Bienvenido a Ruta Libre. Elige cómo te mueves y toca Continuar. '
              'Opciones: silla de ruedas, bastón o andadera, baja visión o '
              'ceguera.'
          : 'Elige tu perfil y toca Guardar.');
    });
  }

  void _pick(MobilityProfile p) {
    HapticFeedback.selectionClick();
    setState(() => _selected = p);
    AppScope.read(context)
        .voice
        .speak('${p.label}. ${widget.firstTime ? 'Toca Continuar' : 'Toca Guardar'}.');
  }

  Future<void> _confirm() async {
    final p = _selected;
    if (p == null || _saving) return;
    setState(() => _saving = true);
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
    final rl = context.rl;

    return Scaffold(
      appBar: widget.firstTime ? null : AppBar(title: const Text('Tu perfil')),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(24, widget.firstTime ? 32 : 8, 24, 16),
                children: [
                  if (widget.firstTime) ...[
                    ExcludeSemantics(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: rl.primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.where_to_vote_outlined,
                              color: rl.onPrimary, size: 32),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Semantics(
                      header: true,
                      child: Text('Bienvenido a Ruta Libre',
                          style: text.displaySmall?.copyWith(height: 1.15)),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    widget.firstTime
                        ? 'Elige cómo te mueves. Adaptamos el mapa, las rutas y '
                            'los avisos a ti. Puedes cambiarlo después.'
                        : 'Adaptamos el mapa, las rutas y los avisos a tu perfil.',
                    style: text.bodyLarge?.copyWith(color: rl.text2, fontSize: 18),
                  ),
                  const SizedBox(height: 24),
                  for (final p in MobilityProfile.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ProfileOption(
                        profile: p,
                        selected: p == _selected,
                        onTap: () => _pick(p),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: _selected == null || _saving ? null : _confirm,
                    child: Text(_selected == null
                        ? 'Elige una opción'
                        : (widget.firstTime ? 'Continuar' : 'Guardar')),
                  ),
                  if (widget.firstTime) ...[
                    const SizedBox(height: 12),
                    Text('Datos del mapa: © colaboradores de OpenStreetMap',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: rl.text2)),
                  ],
                ],
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
        MobilityProfile.lowVision => Icons.visibility_outlined,
        MobilityProfile.blind => Icons.blind,
      };

  @override
  Widget build(BuildContext context) {
    final rl = context.rl;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      label: '${profile.label}. ${profile.description}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected
              ? [BoxShadow(color: rl.primarySoft, spreadRadius: 4)]
              : null,
        ),
        child: Material(
          color: rl.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected ? rl.primary : rl.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              constraints: const BoxConstraints(minHeight: 76),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: selected ? rl.primarySoft : rl.surface2,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_icon,
                        size: 26, color: selected ? rl.primary : rl.text),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile.label,
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: rl.text)),
                        const SizedBox(height: 2),
                        Text(profile.description,
                            style: TextStyle(fontSize: 15, color: rl.text2)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedOpacity(
                    opacity: selected ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: rl.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check, size: 16, color: rl.onPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
