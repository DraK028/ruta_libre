import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_state.dart';
import '../../core/describe.dart';
import '../../core/geo.dart';
import '../../core/theme.dart';
import '../../models/place.dart';
import '../../widgets/base_map.dart';
import '../../widgets/map_markers.dart';
import '../../widgets/ui.dart';
import '../route/route_screen.dart';

/// Ficha de un lugar: accesibilidad, baño, notas y cómo llegar.
class PlaceScreen extends StatefulWidget {
  const PlaceScreen({super.key, required this.place});

  final Place place;

  @override
  State<PlaceScreen> createState() => _PlaceScreenState();
}

class _PlaceScreenState extends State<PlaceScreen> {
  static const _mapHeight = 260.0;
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
    final rl = context.rl;
    final text = Theme.of(context).textTheme;
    final topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: Stack(
        children: [
          // Mapa fijo con el lugar al centro.
          SizedBox(
            height: _mapHeight + topInset + 24,
            child: ExcludeSemantics(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: p.location,
                  initialZoom: 18,
                  interactionOptions:
                      const InteractionOptions(flags: InteractiveFlag.none),
                ),
                children: [
                  osmTiles(context),
                  MarkerLayer(markers: [
                    Marker(
                      point: p.location,
                      width: 72,
                      height: 72,
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: accessColor(p.access).withValues(alpha: 0.3),
                                spreadRadius: 8,
                              ),
                            ],
                          ),
                          child: AccessBadge(access: p.access, size: 52, ring: true),
                        ),
                      ),
                    ),
                    if (app.me != null)
                      Marker(
                          point: app.me!,
                          width: 32,
                          height: 32,
                          child: const UserMarker()),
                  ]),
                ],
              ),
            ),
          ),
          Positioned(
            top: topInset + 12,
            left: 16,
            child: MapIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Volver al mapa',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          Positioned(
            top: topInset + _mapHeight - 34,
            right: 16,
            child: const OsmCredit(),
          ),

          // Ficha.
          Positioned.fill(
            top: topInset + _mapHeight,
            child: Container(
              decoration: BoxDecoration(
                color: rl.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x24000000), blurRadius: 20, offset: Offset(0, -4)),
                ],
              ),
              child: ValueListenableBuilder<LatLng?>(
                valueListenable: app.location.position,
                builder: (context, me, _) {
                  final meters = me == null ? null : distanceMeters(me, p.location);
                  final subtitle = [
                    if (p.name != p.category) p.category,
                    if (me != null && meters != null)
                      '${formatDistanceShort(meters)} ${directionFrom(me, p.location, app.heading)}',
                    if (meters != null) formatDuration(meters / walkingSpeed),
                  ].join(' · ');
                  final tone = accessTone(context, p.access);

                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                        20, 0, 20, 24 + MediaQuery.paddingOf(context).bottom),
                    children: [
                      const SheetHandle(),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Semantics(
                                  header: true,
                                  child: Text(p.name, style: text.headlineMedium),
                                ),
                                if (subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(subtitle,
                                      style:
                                          TextStyle(fontSize: 16, color: rl.text2)),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          ListenButton(
                            onPressed: () => app.voice.speak(
                                describePlace(p, me: me, heading: app.heading)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      MergeSemantics(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: tone.background,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              AccessBadge(access: p.access, size: 36),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.access.label,
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: tone.foreground)),
                                    Text(_capitalize(p.access.explanation),
                                        style: TextStyle(
                                            fontSize: 15, color: rl.text)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (p.kind == PlaceKind.poi) ...[
                            Expanded(
                              child: _Fact(
                                label: 'Baño accesible',
                                value: p.accessibleToilet,
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            child: _Fact(
                              label: 'Guía podotáctil',
                              value: p.tactilePaving,
                            ),
                          ),
                        ],
                      ),
                      if (p.description?.trim().isNotEmpty ?? false) ...[
                        const SizedBox(height: 14),
                        Text.rich(
                          TextSpan(children: [
                            const TextSpan(
                                text: 'Nota: ',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            TextSpan(text: p.description!.trim()),
                          ]),
                          style: TextStyle(fontSize: 16, height: 1.45, color: rl.text),
                        ),
                      ],
                      const SizedBox(height: 18),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => RouteScreen(destination: p)),
                        ),
                        icon: const Icon(Icons.near_me_outlined),
                        label: const Text('Cómo llegar'),
                      ),
                      const SizedBox(height: 18),
                      Divider(color: rl.border),
                      const SizedBox(height: 10),
                      if (_feedbackSent)
                        Semantics(
                          liveRegion: true,
                          child: Text('Gracias por tu ayuda.',
                              style: TextStyle(fontSize: 16, color: rl.okText)),
                        )
                      else
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            Text('¿Es correcta esta información?',
                                style: TextStyle(fontSize: 15, color: rl.text2)),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _PillButton(
                                    label: 'Sí', onTap: () => _feedback(true)),
                                const SizedBox(width: 8),
                                _PillButton(
                                    label: 'No', onTap: () => _feedback(false)),
                              ],
                            ),
                          ],
                        ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => launchUrl(p.osmUrl),
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Ver o corregir en OpenStreetMap'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});
  final String label;
  final bool? value;

  @override
  Widget build(BuildContext context) {
    final rl = context.rl;
    final known = value != null;
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: rl.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 14, color: rl.text2)),
            const SizedBox(height: 4),
            Text(
              !known ? 'Sin dato' : (value! ? 'Sí' : 'No'),
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: known ? rl.text : rl.text2),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 44),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
        ),
        onPressed: onTap,
        child: Text(label),
      );
}
