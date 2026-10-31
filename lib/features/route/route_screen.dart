import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../app_state.dart';
import '../../config.dart';
import '../../core/geo.dart';
import '../../core/route_api.dart';
import '../../core/theme.dart';
import '../../models/place.dart';
import '../../models/route_result.dart';
import '../../services/routing_service.dart';
import '../../widgets/base_map.dart';
import '../../widgets/map_markers.dart';
import '../../widgets/ui.dart';

/// Calcula la ruta a [destination] (o muestra la ruta activa) sobre el mapa,
/// con sus indicaciones en una hoja inferior.
class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key, this.destination});

  /// Null = mostrar la ruta que ya está activa en el mapa.
  final Place? destination;

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  RouteResult? _route;
  String? _error;
  bool _loading = false;
  final _map = MapController();
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.destination == null) {
      _route = AppScope.read(context).route;
    } else {
      _loading = true;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = AppScope.read(context);
      if (widget.destination == null) {
        if (_route != null) app.voice.announce(spokenSummary(_route!));
      } else {
        _calculate();
      }
    });
  }

  Future<void> _calculate() async {
    final app = AppScope.read(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    await app.voice.announce('Calculando una ruta accesible.');
    try {
      final route = await app.routeTo(widget.destination!);
      if (!mounted) return;
      setState(() => _route = route);
      _fit(route);
      await app.voice.speak(
          '${spokenSummary(route)} Toca Iniciar guía por voz para escucharla.');
    } on RoutingException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      await app.voice.speak(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fit(RouteResult route) {
    if (!_mapReady || route.points.length < 2) return;
    _map.fitCamera(CameraFit.bounds(
      bounds: LatLngBounds.fromPoints(route.points),
      padding: _fitPadding,
    ));
  }

  /// Deja libre la tarjeta de arriba y la hoja de abajo.
  EdgeInsets get _fitPadding {
    final h = MediaQuery.sizeOf(context).height;
    return EdgeInsets.fromLTRB(40, 120, 40, h * 0.5 + 24);
  }

  Future<void> _speakAll(AppState app, RouteResult route) async {
    final text = [
      spokenSummary(route),
      for (final s in route.steps) spokenStep(s),
    ].join(' ');
    await app.voice.speak(text);
  }

  IconData _stepIcon(int type) => switch (type) {
        0 || 2 || 4 || 12 => Icons.turn_left,
        1 || 3 || 5 || 13 => Icons.turn_right,
        7 || 8 => Icons.roundabout_left,
        9 => Icons.u_turn_left,
        10 => Icons.flag_outlined,
        11 => Icons.directions_walk,
        _ => Icons.straight,
      };

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final rl = context.rl;
    final route = _route;
    final topInset = MediaQuery.paddingOf(context).top;
    final destination = widget.destination?.name ?? route?.destinationName ?? '';
    final destPoint = widget.destination?.location ??
        (route == null || route.points.isEmpty ? null : route.points.last);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: destPoint ?? app.me ?? AppConfig.pilotCenter,
                  initialZoom: 17,
                  minZoom: 12,
                  maxZoom: 19,
                  onMapReady: () {
                    _mapReady = true;
                    if (_route != null) _fit(_route!);
                  },
                ),
                children: [
                  osmTiles(context),
                  if (route != null) routeLine(context, route),
                  MarkerLayer(markers: [
                    for (final r in app.activeReports())
                      Marker(
                        point: r.location,
                        width: 44,
                        height: 44,
                        child: Center(
                          child: HazardTriangle(
                              color: hazardColor(r.severity), size: 36),
                        ),
                      ),
                    if (destPoint != null)
                      Marker(
                        point: destPoint,
                        width: 44,
                        height: 44,
                        child: Center(
                          child: AccessBadge(
                            access: widget.destination?.access ??
                                Accessibility.yes,
                            size: 34,
                            ring: true,
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

          // Tarjeta superior con el destino.
          Positioned(
            top: topInset + 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 8, 14, 8),
              decoration: BoxDecoration(
                color: rl.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: rl.border),
                boxShadow: cardShadow,
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Volver',
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: Icon(Icons.arrow_back, color: rl.text),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: MergeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.profile.orsProfile == 'wheelchair'
                                ? 'Ruta en silla de ruedas a'
                                : 'Ruta a pie a',
                            style: TextStyle(fontSize: 14, color: rl.text2),
                          ),
                          Text(destination,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  color: rl.text)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: MediaQuery.sizeOf(context).height * 0.48 + 10,
            child: const OsmCredit(),
          ),

          // Hoja con las indicaciones.
          DraggableScrollableSheet(
            initialChildSize: 0.48,
            minChildSize: 0.3,
            maxChildSize: 0.92,
            builder: (context, scroll) => Container(
              decoration: BoxDecoration(
                color: rl.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x24000000),
                      blurRadius: 20,
                      offset: Offset(0, -4)),
                ],
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      children: [
                        const SheetHandle(),
                        const SizedBox(height: 8),
                        ..._sheetBody(app, route),
                      ],
                    ),
                  ),
                  if (route != null)
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                        child: ElevatedButton.icon(
                          onPressed: () => _speakAll(app, route),
                          icon: const Icon(Icons.volume_up_outlined),
                          label: const Text('Iniciar guía por voz'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _sheetBody(AppState app, RouteResult? route) {
    final rl = context.rl;
    if (_loading) {
      return [
        const SizedBox(height: 24),
        Semantics(
          liveRegion: true,
          label: 'Calculando ruta',
          child: const Center(child: CircularProgressIndicator()),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text('Buscando un camino sin obstáculos…',
              style: TextStyle(fontSize: 16, color: rl.text2)),
        ),
      ];
    }
    if (_error != null) {
      return [
        const SizedBox(height: 12),
        const Icon(Icons.wrong_location_outlined,
            size: 48, color: AppTheme.accessNo),
        const SizedBox(height: 12),
        Text(_error!,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: rl.text)),
        const SizedBox(height: 20),
        if (widget.destination != null)
          ElevatedButton(
              onPressed: _calculate, child: const Text('Intentar otra vez')),
      ];
    }
    if (route == null) {
      return [const EmptyNote('No hay una ruta activa.', icon: Icons.route)];
    }

    return [
      Semantics(
        label: spokenSummary(route),
        excludeSemantics: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(formatDuration(route.durationSeconds),
                style: TextStyle(
                    fontSize: 30, fontWeight: FontWeight.w700, color: rl.text)),
            const SizedBox(width: 10),
            Text('· ${formatDistanceShort(route.distanceMeters)}',
                style: TextStyle(fontSize: 18, color: rl.text2)),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (app.profile.avoidSteps)
            Tag(
                label: 'Sin escaleras',
                background: rl.okSoft,
                foreground: rl.okText),
          if (route.avoidedHazards > 0)
            Tag(
              label: route.avoidedHazards == 1
                  ? 'Evita 1 peligro reportado'
                  : 'Evita ${route.avoidedHazards} peligros reportados',
              icon: Icons.warning_amber_rounded,
              background: rl.hazardSoft,
              foreground: rl.hazardText,
            ),
        ],
      ),
      const SizedBox(height: 6),
      for (var i = 0; i < route.steps.length; i++)
        Semantics(
          button: true,
          label: 'Paso ${i + 1}. ${spokenStep(route.steps[i])}',
          excludeSemantics: true,
          child: InkWell(
            onTap: () => app.voice.speak(spokenStep(route.steps[i])),
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: i == route.steps.length - 1
                    ? null
                    : Border(bottom: BorderSide(color: rl.border)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: rl.surface2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_stepIcon(route.steps[i].type),
                        size: 20, color: rl.text),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(route.steps[i].instruction,
                        style: TextStyle(fontSize: 17, color: rl.text)),
                  ),
                  if (route.steps[i].distanceMeters >= 5) ...[
                    const SizedBox(width: 10),
                    Text(formatDistanceShort(route.steps[i].distanceMeters),
                        style: TextStyle(fontSize: 15, color: rl.text2)),
                  ],
                ],
              ),
            ),
          ),
        ),
      const SizedBox(height: 10),
      Text(
        'Ruta sugerida con datos de OpenStreetMap: puede haber tramos sin '
        'información. Confirma el camino al avanzar.',
        style: TextStyle(fontSize: 14, color: rl.text2),
      ),
    ];
  }
}
