import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_state.dart';
import '../../config.dart';
import '../../core/describe.dart';
import '../../core/geo.dart';
import '../../core/route_api.dart';
import '../../core/theme.dart';
import '../../core/voice_commands.dart';
import '../../models/place.dart';
import '../../widgets/map_markers.dart';
import '../nearby/nearby_screen.dart';
import '../place/place_screen.dart';
import '../report/new_report_screen.dart';
import '../report/report_screen.dart';
import '../route/route_screen.dart';
import '../settings/settings_screen.dart';

/// Pantalla principal: mapa con lugares, peligros y ruta activa.
///
/// El mapa es la vista para quien ve; todo lo que muestra también está en
/// "Cerca", que es la vista para quien usa lector de pantalla.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  /// A partir de este zoom se muestran los cruces.
  static const _crossingZoom = 17.0;

  final _map = MapController();
  bool _showCrossings = true;
  bool _followMe = true;
  bool _listening = false;
  bool _mapReady = false;
  bool _showLoadHere = false;
  LatLng _cameraCenter = AppConfig.pilotCenter;

  /// Centros de las zonas ya descargadas.
  final List<LatLng> _loadedCenters = [AppConfig.pilotCenter];

  late final AppState _app;

  @override
  void initState() {
    super.initState();
    _app = AppScope.read(context);
    _app.location.position.addListener(_onMove);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final error = await _app.start();
    if (!mounted) return;
    if (error != null) {
      _snack(error);
      await _app.voice.speak(error);
      return;
    }
    final accessible = _app.allPlaces
        .where((p) =>
            p.kind == PlaceKind.poi && p.access == Accessibility.yes)
        .length;
    final hazards = _app.activeReports().length;
    await _app.voice.announce(
      'Mapa. $accessible lugares accesibles registrados en la zona'
      '${hazards == 0 ? '' : ' y $hazards peligros reportados'}. '
      'Toca Cerca para escucharlos, o Hablar para pedir algo por voz.',
    );
  }

  void _onMove() {
    final me = _app.me;
    if (me == null || !_followMe || !_mapReady) return;
    _map.move(me, _map.camera.zoom);
  }

  @override
  void dispose() {
    _app.location.position.removeListener(_onMove);
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  void _centerOnMe() {
    final me = _app.me;
    if (me == null) {
      _app.voice.speak('Todavía no tengo tu ubicación.');
      return;
    }
    setState(() => _followMe = true);
    if (_mapReady) _map.move(me, 18);
    _app.voice.announce('Centrado en tu ubicación.');
  }

  Future<void> _whereAmI() async {
    final me = _app.me;
    if (me == null) {
      await _app.voice.speak('Todavía no tengo tu ubicación.');
      return;
    }
    final nearest = _app.placesNearby(limit: 1);
    if (nearest.isEmpty) {
      await _app.voice.speak('No hay lugares registrados cerca de ti.');
      return;
    }
    final p = nearest.first;
    await _app.voice.speak(
      'Estás a ${formatDistance(distanceMeters(me, p.location))} de ${p.name}, '
      '${directionFrom(me, p.location, _app.heading)}.',
    );
  }

  Future<void> _listen() async {
    if (_listening) return;
    setState(() => _listening = true);
    await _app.voice.speak('Te escucho');
    final phrase = await _app.voice.listenOnce();
    if (!mounted) return;
    setState(() => _listening = false);
    if (phrase == null) {
      await _app.voice.speak('No escuché nada. Intenta otra vez.');
      return;
    }
    switch (parseVoiceCommand(phrase)) {
      case VoiceCommand.nearby:
        await _push(const NearbyScreen());
      case VoiceCommand.report:
        await _push(const NewReportScreen());
      case VoiceCommand.whereAmI:
        await _whereAmI();
      case VoiceCommand.clearRoute:
        _app.clearRoute();
        await _app.voice.speak('Ruta quitada.');
      case VoiceCommand.settings:
        await _push(const SettingsScreen());
      case VoiceCommand.unknown:
        await _app.voice.speak(
          'No entendí "$phrase". Puedes decir: qué hay cerca, reportar un '
          'peligro, dónde estoy o quitar ruta.',
        );
    }
  }

  void _showLegend() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      builder: (_) => const SafeArea(
        child: Padding(padding: EdgeInsets.all(20), child: AccessLegend()),
      ),
    );
  }

  bool get _outsideLoadedArea => _loadedCenters.every((c) =>
      distanceMeters(_cameraCenter, c) > AppConfig.pilotRadiusMeters * 0.8);

  Future<void> _loadHere() async {
    final center = _cameraCenter;
    await _app.loadPlaces(center);
    if (!mounted) return;
    final error = _app.placesError;
    if (error != null) {
      _snack(error);
      await _app.voice.speak(error);
      return;
    }
    setState(() {
      _loadedCenters.add(center);
      _showLoadHere = _outsideLoadedArea;
    });
    await _app.voice.announce('Lugares de esta zona descargados.');
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final now = DateTime.now();
    final route = app.route;

    final places = app.visiblePlaces
        .where((p) => _showCrossings || p.kind == PlaceKind.poi)
        .toList()
      // Los cruces debajo, los lugares encima.
      ..sort((a, b) => b.kind.index.compareTo(a.kind.index));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ruta Libre'),
        actions: [
          IconButton(
            iconSize: 32,
            tooltip: 'Qué significan los colores',
            icon: const Icon(Icons.info_outline),
            onPressed: _showLegend,
          ),
          IconButton(
            iconSize: 32,
            tooltip: 'Centrar en mi ubicación',
            icon: const Icon(Icons.my_location),
            onPressed: _centerOnMe,
          ),
          IconButton(
            iconSize: 32,
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings),
            onPressed: () => _push(const SettingsScreen()),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: app.me ?? AppConfig.pilotCenter,
                    initialZoom: 17,
                    minZoom: 12,
                    maxZoom: 19,
                    onMapReady: () {
                      _mapReady = true;
                      _onMove();
                    },
                    onPositionChanged: (camera, hasGesture) {
                      // Solo se redibuja si cambia algo visible; arrastrar el
                      // mapa no debe reconstruir cientos de marcadores por cuadro.
                      _cameraCenter = camera.center;
                      final crossings = camera.zoom >= _crossingZoom;
                      final outside = _outsideLoadedArea;
                      final follow = hasGesture ? false : _followMe;
                      if (crossings != _showCrossings ||
                          outside != _showLoadHere ||
                          follow != _followMe) {
                        setState(() {
                          _showCrossings = crossings;
                          _showLoadHere = outside;
                          _followMe = follow;
                        });
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: AppConfig.packageName,
                      maxZoom: 19,
                    ),
                    if (route != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: route.points,
                            strokeWidth: 8,
                            color: const Color(0xFF2F80ED),
                            borderStrokeWidth: 3,
                            borderColor: Colors.white,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        for (final p in places)
                          Marker(
                            point: p.location,
                            width: p.kind == PlaceKind.crossing ? 30 : 44,
                            height: p.kind == PlaceKind.crossing ? 30 : 44,
                            child: PlaceMarker(
                              place: p,
                              semanticLabel: describePlace(p,
                                  me: app.me, heading: app.heading),
                              onTap: () => _push(PlaceScreen(place: p)),
                            ),
                          ),
                        for (final r in app.activeReports(now))
                          Marker(
                            point: r.location,
                            width: 56,
                            height: 56,
                            child: HazardMarker(
                              report: r,
                              semanticLabel: describeReport(r, now,
                                  me: app.me, heading: app.heading),
                              onTap: () => _push(ReportScreen(reportId: r.id)),
                            ),
                          ),
                        if (app.me != null)
                          Marker(
                            point: app.me!,
                            width: 28,
                            height: 28,
                            child: const UserMarker(),
                          ),
                      ],
                    ),
                    RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution(
                          'OpenStreetMap contributors',
                          onTap: () => launchUrl(
                              Uri.parse('https://openstreetmap.org/copyright')),
                        ),
                      ],
                    ),
                  ],
                ),
                if (app.loadingPlaces)
                  const _TopBanner(
                    icon: Icons.downloading,
                    text: 'Descargando lugares de la zona…',
                  ),
                if (!app.loadingPlaces && _showLoadHere)
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: ElevatedButton.icon(
                      onPressed: _loadHere,
                      icon: const Icon(Icons.travel_explore, size: 28),
                      label: const Text('Buscar lugares aquí'),
                    ),
                  ),
              ],
            ),
          ),
          if (route != null)
            _RouteBanner(
              summary: spokenSummary(route),
              onSteps: () => _push(const RouteScreen()),
              onClear: () {
                app.clearRoute();
                app.voice.announce('Ruta quitada.');
              },
            ),
          _BottomControls(
            onlyAccessible: app.settings.onlyAccessible,
            listening: _listening,
            onToggleFilter: (v) {
              app.updateSettings(app.settings.copyWith(onlyAccessible: v));
              app.voice.announce(v
                  ? 'Mostrando solo lugares accesibles.'
                  : 'Mostrando todos los lugares.');
            },
            onNearby: () => _push(const NearbyScreen()),
            onReport: () => _push(const NewReportScreen()),
            onListen: _listen,
          ),
        ],
      ),
    );
  }
}

class _TopBanner extends StatelessWidget {
  const _TopBanner({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.accent, width: 2),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.accent, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteBanner extends StatelessWidget {
  const _RouteBanner({
    required this.summary,
    required this.onSteps,
    required this.onClear,
  });

  final String summary;
  final VoidCallback onSteps;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(summary, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onSteps,
                  icon: const Icon(Icons.list, size: 28),
                  label: const Text('Indicaciones'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.close, size: 28),
                  label: const Text('Quitar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.onlyAccessible,
    required this.listening,
    required this.onToggleFilter,
    required this.onNearby,
    required this.onReport,
    required this.onListen,
  });

  final bool onlyAccessible;
  final bool listening;
  final ValueChanged<bool> onToggleFilter;
  final VoidCallback onNearby;
  final VoidCallback onReport;
  final VoidCallback onListen;

  @override
  Widget build(BuildContext context) {
    Widget action(IconData icon, String label, VoidCallback onTap,
        {Color bg = AppTheme.accent, Color fg = AppTheme.onAccent}) {
      return Expanded(
        child: Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: Material(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: SizedBox(
                height: 92,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 36, color: fg),
                    const SizedBox(height: 4),
                    Text(label,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: fg)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Material(
        color: AppTheme.background,
        child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              title: Text('Solo lugares accesibles',
                  style: Theme.of(context).textTheme.bodyLarge),
              value: onlyAccessible,
              onChanged: onToggleFilter,
            ),
            Row(
              children: [
                action(Icons.near_me, 'Cerca', onNearby),
                const SizedBox(width: 10),
                action(Icons.report, 'Reportar', onReport,
                    bg: AppTheme.danger, fg: AppTheme.onAccent),
                const SizedBox(width: 10),
                action(listening ? Icons.hearing : Icons.mic,
                    listening ? 'Escucho…' : 'Hablar', onListen,
                    bg: AppTheme.surface, fg: AppTheme.text),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }
}
