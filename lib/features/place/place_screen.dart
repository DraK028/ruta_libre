import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_state.dart';
import '../../core/describe.dart';
import '../../core/theme.dart';
import '../../models/place.dart';
import '../../widgets/map_markers.dart';
import '../route/route_screen.dart';

/// Ficha de un lugar: accesibilidad, baño, notas y cómo llegar.
class PlaceScreen extends StatefulWidget {
  const PlaceScreen({super.key, required this.place});

  final Place place;

  @override
  State<PlaceScreen> createState() => _PlaceScreenState();
}

class _PlaceScreenState extends State<PlaceScreen> {
  bool _feedbackSent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = AppScope.read(context);
      app.voice.announce(
          describePlace(widget.place, me: app.me, heading: app.heading));
    });
  }

  Future<void> _feedback(bool correct) async {
    final app = AppScope.read(context);
    await app.saveFeedback(widget.place, correct: correct);
    setState(() => _feedbackSent = true);
    await app.voice.speak(correct
        ? 'Gracias por confirmarlo.'
        : 'Gracias. Lo revisaremos para corregirlo en OpenStreetMap.');
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = widget.place;
    final text = Theme.of(context).textTheme;

    String yesNo(bool? v, String yes, String no) =>
        v == null ? 'Sin dato' : (v ? yes : no);

    return Scaffold(
      appBar: AppBar(title: Text(p.category)),
      body: SafeArea(
        child: ValueListenableBuilder<LatLng?>(
          valueListenable: app.location.position,
          builder: (context, me, _) {
            final where = whereIs(p.location, me, app.heading);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(p.name, style: text.displaySmall),
                if (where.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(where, style: text.titleLarge),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: accessColor(p.access).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accessColor(p.access), width: 3),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: accessColor(p.access),
                        child: Icon(accessIcon(p.access),
                            color: Colors.white, size: 36),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.access.label, style: text.headlineMedium),
                            Text(p.access.explanation, style: text.bodyLarge),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (p.kind == PlaceKind.poi)
                  _InfoRow(
                    icon: Icons.wc,
                    label: 'Baño accesible',
                    value: yesNo(p.accessibleToilet, 'Sí', 'No'),
                  ),
                _InfoRow(
                  icon: Icons.texture,
                  label: 'Guía podotáctil',
                  value: yesNo(p.tactilePaving, 'Sí', 'No'),
                ),
                if (p.description?.trim().isNotEmpty ?? false)
                  _InfoRow(icon: Icons.notes, label: 'Notas', value: p.description!),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => app.voice.speak(
                      describePlace(p, me: me, heading: app.heading)),
                  icon: const Icon(Icons.volume_up, size: 32),
                  label: const Text('Escuchar'),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => RouteScreen(destination: p)),
                  ),
                  icon: const Icon(Icons.directions, size: 32),
                  label: const Text('Cómo llegar'),
                ),
                const SizedBox(height: 24),
                Text('¿Es correcta esta información?', style: text.titleLarge),
                const SizedBox(height: 8),
                if (_feedbackSent)
                  Text('Gracias por tu ayuda.',
                      style: text.bodyLarge?.copyWith(color: AppTheme.success))
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _feedback(true),
                          child: const Text('Sí'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _feedback(false),
                          child: const Text('No'),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => launchUrl(p.osmUrl),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Ver o corregir en OpenStreetMap',
                      style: TextStyle(fontSize: 18)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: AppTheme.accent),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: text.bodyMedium?.copyWith(color: AppTheme.textMuted)),
                  Text(value, style: text.titleLarge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
