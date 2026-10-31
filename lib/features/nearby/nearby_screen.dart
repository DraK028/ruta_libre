import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../app_state.dart';
import '../../core/describe.dart';
import '../../core/text_utils.dart';
import '../../core/theme.dart';
import '../../models/place.dart';
import '../../widgets/ui.dart';
import '../place/place_screen.dart';
import '../report/report_screen.dart';

/// "¿Qué hay cerca?" a pantalla completa. Se abre con el comando de voz y
/// es la misma lista que la hoja del mapa, pensada para lector de pantalla.
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
        'Cerca de ti. Toca Escuchar para oír los más cercanos, o recorre la '
        'lista. ${hazards == 0 ? 'No hay peligros reportados.' : 'Hay $hazards peligros reportados en la pestaña Peligros.'}',
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
    final rl = context.rl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cerca de ti'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ListenButton(onPressed: () => _speakTop(app), label: 'Escuchar'),
          ),
        ],
      ),
      body: SafeArea(
        // Se redibuja al moverse para que distancias y direcciones sigan vigentes.
        child: ValueListenableBuilder<LatLng?>(
          valueListenable: app.location.position,
          builder: (context, me, _) {
            final places = _filtered(app);
            final hazards = app.reportsNearby();
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                Segmented<bool>(
                  values: const [false, true],
                  selected: _showHazards,
                  labelOf: (h) => h ? 'Peligros · ${hazards.length}' : 'Lugares',
                  onChanged: (h) => setState(() => _showHazards = h),
                ),
                const SizedBox(height: 12),
                if (!_showHazards)
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Buscar farmacia, banco, baños…',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                if (me == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Sin ubicación todavía: las distancias se miden desde '
                      'el centro de la zona piloto.',
                      style: TextStyle(fontSize: 14, color: rl.text2),
                    ),
                  ),
                const SizedBox(height: 4),
                if (_showHazards) ...[
                  if (hazards.isEmpty)
                    const EmptyNote('No hay peligros reportados cerca.',
                        icon: Icons.verified_outlined),
                  for (final r in hazards)
                    HazardRow(
                      report: r,
                      me: me,
                      heading: app.heading,
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => ReportScreen(reportId: r.id))),
                    ),
                ] else ...[
                  if (places.isEmpty)
                    EmptyNote(app.loadingPlaces
                        ? 'Descargando lugares…'
                        : 'No encontré lugares con ese nombre.'),
                  for (final p in places)
                    PlaceRow(
                      place: p,
                      me: me,
                      heading: app.heading,
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
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
