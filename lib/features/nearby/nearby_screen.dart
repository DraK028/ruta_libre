import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../app_state.dart';
import '../../core/describe.dart';
import '../../core/text_utils.dart';
import '../../core/theme.dart';
import '../../models/place.dart';
import '../../models/report.dart';
import '../../widgets/map_markers.dart';
import '../place/place_screen.dart';
import '../report/report_screen.dart';

/// "¿Qué hay cerca?": la vista del mapa en forma de lista, para lector de
/// pantalla y voz. Ordenada por distancia y con dirección relativa.
class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key});

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  bool _showHazards = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = AppScope.read(context);
      final hazards = app.reportsNearby().length;
      app.voice.announce(
        'Cerca de ti. Toca Escuchar los más cercanos, o recorre la lista. '
        '${hazards == 0 ? 'No hay peligros reportados.' : 'Hay $hazards peligros reportados en la pestaña Peligros.'}',
      );
    });
  }

  List<Place> _filtered(AppState app) {
    final q = normalize(_query);
    final list = app.placesNearby(limit: 60);
    if (q.isEmpty) return list.take(30).toList();
    return list
        .where((p) =>
            normalize(p.name).contains(q) || normalize(p.category).contains(q))
        .take(30)
        .toList();
  }

  Future<void> _speakTop(AppState app) async {
    final me = app.me;
    final String text;
    if (_showHazards) {
      final list = app.reportsNearby().take(3).toList();
      final now = DateTime.now();
      text = list.isEmpty
          ? 'No hay peligros reportados cerca.'
          : list
              .map((r) => describeReport(r, now, me: me, heading: app.heading))
              .join(' ');
    } else {
      final list = _filtered(app).take(5).toList();
      text = list.isEmpty
          ? 'No encontré lugares.'
          : list
              .map((p) => '${p.name}, ${p.access.label.toLowerCase()}, '
                  '${whereIs(p.location, me, app.heading)}.')
              .join(' ');
    }
    await app.voice.speak(text);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Cerca de ti')),
      body: SafeArea(
        // Se redibuja al moverse para que distancias y direcciones sigan vigentes.
        child: ValueListenableBuilder<LatLng?>(
          valueListenable: app.location.position,
          builder: (context, me, _) {
            final now = DateTime.now();
            final places = _filtered(app);
            final hazards = app.reportsNearby();
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (me == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Sin ubicación todavía: las distancias se miden desde '
                      'el centro de la zona piloto.',
                      style: text.bodyMedium?.copyWith(color: AppTheme.textMuted),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: _Tab(
                        label: 'Lugares',
                        selected: !_showHazards,
                        onTap: () => setState(() => _showHazards = false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Tab(
                        label: 'Peligros (${hazards.length})',
                        selected: _showHazards,
                        onTap: () => setState(() => _showHazards = true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _speakTop(app),
                  icon: const Icon(Icons.volume_up, size: 32),
                  label: const Text('Escuchar los más cercanos'),
                ),
                const SizedBox(height: 12),
                if (!_showHazards)
                  TextField(
                    style: text.titleLarge,
                    decoration: const InputDecoration(
                      labelText: 'Buscar (farmacia, banco, baños…)',
                      prefixIcon: Icon(Icons.search, size: 28),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                const SizedBox(height: 12),
                if (_showHazards) ...[
                  if (hazards.isEmpty)
                    const _Empty('No hay peligros reportados cerca.'),
                  for (final r in hazards)
                    _HazardTile(
                      report: r,
                      subtitle: whereIs(r.location, me, app.heading),
                      semantic: describeReport(r, now, me: me, heading: app.heading),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => ReportScreen(reportId: r.id))),
                    ),
                ] else ...[
                  if (places.isEmpty)
                    _Empty(app.loadingPlaces
                        ? 'Descargando lugares…'
                        : 'No encontré lugares con ese nombre.'),
                  for (final p in places)
                    _PlaceTile(
                      place: p,
                      subtitle: whereIs(p.location, me, app.heading),
                      semantic: describePlace(p, me: me, heading: app.heading),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => PlaceScreen(place: p))),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: selected
          ? ElevatedButton(onPressed: onTap, child: Text(label))
          : OutlinedButton(onPressed: onTap, child: Text(label)),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
      );
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({
    required this.place,
    required this.subtitle,
    required this.semantic,
    required this.onTap,
  });

  final Place place;
  final String subtitle;
  final String semantic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: semantic,
      excludeSemantics: true,
      child: Card(
        color: AppTheme.surface,
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: accessColor(place.access),
                  child: Icon(accessIcon(place.access), color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(place.name, style: text.titleLarge),
                      Text('${place.category} · ${place.access.label}',
                          style: text.bodyMedium?.copyWith(color: AppTheme.textMuted)),
                      if (subtitle.isNotEmpty)
                        Text(subtitle, style: text.bodyLarge),
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

class _HazardTile extends StatelessWidget {
  const _HazardTile({
    required this.report,
    required this.subtitle,
    required this.semantic,
    required this.onTap,
  });

  final Report report;
  final String subtitle;
  final String semantic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: semantic,
      excludeSemantics: true,
      child: Card(
        color: AppTheme.surface,
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.warning,
                    size: 44,
                    color: report.severity == Severity.high
                        ? AppTheme.hazard
                        : AppTheme.accessLimited),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(report.type.label, style: text.titleLarge),
                      Text('Gravedad ${report.severity.label.toLowerCase()}',
                          style: text.bodyMedium?.copyWith(color: AppTheme.textMuted)),
                      if (subtitle.isNotEmpty) Text(subtitle, style: text.bodyLarge),
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
