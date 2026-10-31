import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app_state.dart';
import '../../config.dart';
import '../../core/describe.dart';
import '../../core/geo.dart';
import '../../core/route_api.dart';
import '../../core/text_utils.dart';
import '../../core/theme.dart';
import '../../core/voice_commands.dart';
import '../../models/place.dart';
import '../../models/report.dart';
import '../../widgets/base_map.dart';
import '../../widgets/map_markers.dart';
import '../../widgets/ui.dart';
import '../nearby/nearby_screen.dart';
import '../place/place_screen.dart';
import '../report/new_report_screen.dart';
import '../report/report_screen.dart';
import '../route/route_screen.dart';
import '../settings/settings_screen.dart';

/// Filtros rápidos por tipo de lugar.
enum PlaceFilter {
  pharmacy('Farmacias', Icons.local_pharmacy_outlined),
  toilets('Baños', Icons.wc),
  transport('Transporte', Icons.directions_bus_outlined);

  const PlaceFilter(this.label, this.icon);
  final String label;
  final IconData icon;

  bool matches(Place p) => switch (this) {
        PlaceFilter.pharmacy => p.category == 'Farmacia',
        PlaceFilter.toilets =>
          p.category == 'Baños públicos' || p.accessibleToilet == true,
        PlaceFilter.transport =>
          const {'Parada de autobús', 'Estación', 'Elevador'}.contains(p.category),
      };
}

/// Pantalla principal: mapa a pantalla completa, búsqueda y filtros arriba,
/// y la hoja "Cerca de ti" abajo.
///
/// Todo lo que muestra el mapa también está en la hoja, que es la vista
/// para quien usa lector de pantalla.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  /// A partir de este zoom se muestran los cruces.
  static const _crossingZoom = 17.0;
  static const _sheetInitial = 0.36;
  static const _sheetMax = 0.92;

  final _map = MapController();
  final _sheet = DraggableScrollableController();
  final _search = TextEditingController();
  final _searchFocus = FocusNode();

  /// Altura actual de la hoja (fracción de la pantalla).
  final _sheetSize = ValueNotifier<double>(_sheetInitial);

  bool _showCrossings = true;
  bool _followMe = true;
  bool _listening = false;
  bool _mapReady = false;
  bool _showLoadHere = false;
  bool _showHazards = false;
  PlaceFilter? _filter;
  String _query = '';
  LatLng _cameraCenter = AppConfig.pilotCenter;

  late final AppState _app;

  @override
  void initState() {
    super.initState();
    _app = AppScope.read(context);
    _app.location.position.addListener(_onMove);
    _searchFocus.addListener(() {
      // Al buscar se sube la hoja para ver los resultados.
      if (_searchFocus.hasFocus && _sheet.isAttached && _sheet.size < 0.55) {
        _sheet.animateTo(0.6,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
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
    final accessible = _app
        .placesNearby(limit: 1000)
        .where((p) => p.access == Accessibility.yes)
        .length;
    final hazards = _app.activeReports().length;
    await _app.voice.announce(
      'Mapa. $accessible lugares accesibles registrados en la zona'
      '${hazards == 0 ? '' : ' y $hazards peligros reportados'}. '
      'Abajo está la lista Cerca de ti. Arriba puedes buscar o hablar.',
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
    _sheet.dispose();
    _search.dispose();
    _searchFocus.dispose();
    _sheetSize.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  // ---------- Filtros y búsqueda ----------

  bool _matches(Place p) {
    final f = _filter;
    if (f != null && !f.matches(p)) return false;
    final q = normalize(_query);
    if (q.isEmpty) return true;
    return normalize(p.name).contains(q) || normalize(p.category).contains(q);
  }

  bool get _searching => _query.trim().isNotEmpty || _filter != null;

  List<Place> _listPlaces(AppState app) =>
      app.placesNearby(limit: 200).where(_matches).take(40).toList();

  void _toggleOnlyAccessible() {
    final v = !_app.settings.onlyAccessible;
    _app.updateSettings(_app.settings.copyWith(onlyAccessible: v));
    _app.voice.announce(
        v ? 'Mostrando solo lugares accesibles.' : 'Mostrando todos los lugares.');
  }

  void _toggleFilter(PlaceFilter f) {
    setState(() {
      _filter = _filter == f ? null : f;
      _showHazards = false;
    });
    final count = _listPlaces(_app).length;
    _app.voice.announce(_filter == null
        ? 'Sin filtro.'
        : '${f.label}: $count ${count == 1 ? 'resultado' : 'resultados'}.');
  }

  // ---------- Acciones ----------

  void _centerOnMe() {
    final me = _app.me;
    if (me == null) {
      setState(() => _followMe = true);
      // Puede que la ubicación estuviera apagada al abrir: se vuelve a pedir.
      _app.retryLocation().then((error) {
        final message = error ?? 'Buscando tu ubicación…';
        if (!mounted) return;
        _snack(message);
        _app.voice.speak(message);
      });
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

  Future<void> _speakList() async {
    final me = _app.me;
    final String text;
    if (_showHazards) {
      final list = _app.reportsNearby().take(3).toList();
      final now = DateTime.now();
      text = list.isEmpty
          ? 'No hay peligros reportados cerca.'
          : list
              .map((r) => describeReport(r, now, me: me, heading: _app.heading))
              .join(' ');
    } else {
      final list = _listPlaces(_app).take(5).toList();
      text = list.isEmpty
          ? 'No encontré lugares.'
          : list
              .map((p) => '${p.name}, ${p.access.label.toLowerCase()}, '
                  '${whereIs(p.location, me, _app.heading)}.')
              .join(' ');
    }
    await _app.voice.speak(text);
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
        // Lo que no es un comando se busca como lugar.
        _search.text = phrase;
        setState(() {
          _query = phrase;
          _showHazards = false;
        });
        final found = _listPlaces(_app);
        await _app.voice.speak(found.isEmpty
            ? 'No encontré "$phrase". Puedes decir: qué hay cerca, reportar '
                'un peligro, dónde estoy o quitar ruta.'
            : 'Encontré ${found.length} resultados para $phrase. '
                'El más cercano: ${found.first.name}, '
                '${whereIs(found.first.location, _app.me, _app.heading)}.');
    }
  }

  void _showLegend() {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: AccessLegend(),
        ),
      ),
    );
  }

  bool get _outsideLoadedArea => outsideZones(
        _cameraCenter,
        _app.loadedCenters,
        AppConfig.pilotRadiusMeters.toDouble(),
        margin: 0.8,
      );

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
    setState(() => _showLoadHere = _outsideLoadedArea);
    await _app.voice.announce('Lugares de esta zona descargados.');
  }

  // ---------- Vista ----------

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final now = DateTime.now();
    final route = app.route;

    final places = app.visiblePlaces
        .where((p) =>
            (_showCrossings && !_searching && p.kind == PlaceKind.crossing) ||
            (p.kind == PlaceKind.poi && _matches(p)))
        .toList()
      // Los cruces debajo, los lugares encima.
      ..sort((a, b) => b.kind.index.compareTo(a.kind.index));

    return Scaffold(
      body: LayoutBuilder(builder: (context, constraints) {
        final height = constraints.maxHeight;
        final sheetMin = (190 / height).clamp(0.16, 0.4);
        return Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: app.me ?? AppConfig.pilotCenter,
                  initialZoom: 17,
                  minZoom: 12,
                  maxZoom: 19,
                  onTap: (_, _) => FocusScope.of(context).unfocus(),
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
                  osmTiles(context),
                  if (route != null) routeLine(context, route),
                  MarkerLayer(
                    markers: [
                      for (final p in places)
                        Marker(
                          point: p.location,
                          width: 44,
                          height: 44,
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
                          width: 52,
                          height: 52,
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
                          width: 32,
                          height: 32,
                          child: const UserMarker(),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Botones flotantes: suben y bajan con la hoja.
            ValueListenableBuilder<double>(
              valueListenable: _sheetSize,
              builder: (context, size, _) {
                final bottom = size * height + 12;
                final hidden = size > 0.62;
                return Positioned(
                  left: 0,
                  right: 0,
                  bottom: bottom,
                  child: IgnorePointer(
                    ignoring: hidden,
                    child: ExcludeSemantics(
                      excluding: hidden,
                      child: AnimatedOpacity(
                        opacity: hidden ? 0 : 1,
                        duration: const Duration(milliseconds: 150),
                        child: _FloatingControls(
                          onLegend: _showLegend,
                          onCenter: _centerOnMe,
                          onReport: () => _push(const NewReportScreen()),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Hoja "Cerca de ti".
            NotificationListener<DraggableScrollableNotification>(
              onNotification: (n) {
                _sheetSize.value = n.extent;
                return false;
              },
              child: DraggableScrollableSheet(
                controller: _sheet,
                initialChildSize: _sheetInitial.clamp(sheetMin, _sheetMax),
                minChildSize: sheetMin,
                maxChildSize: _sheetMax,
                snap: true,
                // Punto intermedio solo si cabe entre el mínimo y el máximo.
                snapSizes: _sheetInitial > sheetMin + 0.02 ? const [_sheetInitial] : null,
                builder: (context, scroll) => _NearbySheet(
                  scroll: scroll,
                  app: app,
                  places: _listPlaces(app),
                  hazards: app.reportsNearby(),
                  showHazards: _showHazards,
                  title: _searching ? 'Resultados' : 'Cerca de ti',
                  subtitle: _searching
                      ? [
                          if (_filter != null) _filter!.label,
                          if (_query.trim().isNotEmpty) '“${_query.trim()}”',
                        ].join(' · ')
                      : app.me == null
                          ? 'Zona piloto: UPIICSA (sin ubicación)'
                          : app.nearPilot
                              ? 'Alrededores de UPIICSA'
                              : 'Alrededores de tu ubicación',
                  onTab: (h) => setState(() => _showHazards = h),
                  onListen: _speakList,
                  onPlace: (p) => _push(PlaceScreen(place: p)),
                  onHazard: (r) => _push(ReportScreen(reportId: r.id)),
                ),
              ),
            ),

            // Búsqueda, filtros y avisos arriba.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SearchBar(
                        controller: _search,
                        focus: _searchFocus,
                        listening: _listening,
                        onChanged: (v) => setState(() {
                          _query = v;
                          _showHazards = false;
                        }),
                        onClear: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                        onMic: _listen,
                        onSettings: () => _push(const SettingsScreen()),
                      ),
                      const SizedBox(height: 10),
                      if (route != null)
                        _RouteCard(
                          title: route.destinationName,
                          detail: '${formatDuration(route.durationSeconds)} · '
                              '${formatDistanceShort(route.distanceMeters)}',
                          semantic: spokenSummary(route),
                          onSteps: () => _push(const RouteScreen()),
                          onClear: () {
                            app.clearRoute();
                            app.voice.announce('Ruta quitada.');
                          },
                        )
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          child: Row(
                            children: [
                              FilterPill(
                                label: 'Solo accesibles',
                                selected: app.settings.onlyAccessible,
                                onTap: _toggleOnlyAccessible,
                              ),
                              for (final f in PlaceFilter.values) ...[
                                const SizedBox(width: 8),
                                FilterPill(
                                  label: f.label,
                                  icon: f.icon,
                                  selected: _filter == f,
                                  onTap: () => _toggleFilter(f),
                                ),
                              ],
                            ],
                          ),
                        ),
                      if (app.loadingPlaces)
                        const _StatusPill(
                          icon: null,
                          text: 'Descargando lugares de la zona…',
                        )
                      else if (_showLoadHere)
                        Center(
                          child: _StatusPill(
                            icon: Icons.travel_explore,
                            text: 'Buscar lugares aquí',
                            onTap: _loadHere,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focus,
    required this.listening,
    required this.onChanged,
    required this.onClear,
    required this.onMic,
    required this.onSettings,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final bool listening;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onMic;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final rl = context.rl;
    return Container(
      decoration: BoxDecoration(
        color: rl.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rl.border),
        boxShadow: cardShadow,
      ),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      child: Row(
        children: [
          Icon(Icons.search, color: rl.text2, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => focus.unfocus(),
              style: TextStyle(fontSize: 17, color: rl.text),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                hintText: 'Buscar farmacia, baño, banco…',
                hintStyle: TextStyle(fontSize: 17, color: rl.text2),
                semanticCounterText: '',
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Borrar búsqueda',
                    onPressed: onClear,
                    icon: Icon(Icons.close, color: rl.text2),
                  ),
          ),
          IconButton(
            tooltip: listening ? 'Escuchando' : 'Hablar o buscar por voz',
            onPressed: onMic,
            style: IconButton.styleFrom(
              backgroundColor: listening ? rl.primary : rl.primarySoft,
              foregroundColor: listening ? rl.onPrimary : rl.primary,
              minimumSize: const Size(44, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(listening ? Icons.hearing : Icons.mic_none),
          ),
          const SizedBox(width: 2),
          IconButton(
            tooltip: 'Ajustes y perfil',
            onPressed: onSettings,
            style: IconButton.styleFrom(
              minimumSize: const Size(44, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: Icon(Icons.person_outline, color: rl.text2),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.icon, required this.text, this.onTap});

  /// Null = mostrar un indicador de progreso.
  final IconData? icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rl = context.rl;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Semantics(
        liveRegion: onTap == null,
        button: onTap != null,
        child: Material(
          color: rl.surface,
          shape: StadiumBorder(side: BorderSide(color: rl.border)),
          elevation: 2,
          shadowColor: Colors.black26,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon == null)
                    const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5))
                  else
                    Icon(icon, size: 20, color: rl.primary),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(text,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: onTap == null ? rl.text : rl.primary)),
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

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.title,
    required this.detail,
    required this.semantic,
    required this.onSteps,
    required this.onClear,
  });

  final String title;
  final String detail;
  final String semantic;
  final VoidCallback onSteps;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final rl = context.rl;
    return Container(
      decoration: BoxDecoration(
        color: rl.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rl.border),
        boxShadow: cardShadow,
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: rl.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.directions, color: rl.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              label: semantic,
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ruta a $title',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: rl.text)),
                  Text(detail, style: TextStyle(fontSize: 14, color: rl.text2)),
                ],
              ),
            ),
          ),
          TextButton(onPressed: onSteps, child: const Text('Indicaciones')),
          IconButton(
            tooltip: 'Quitar ruta',
            onPressed: onClear,
            icon: Icon(Icons.close, color: rl.text2),
          ),
        ],
      ),
    );
  }
}

class _FloatingControls extends StatelessWidget {
  const _FloatingControls({
    required this.onLegend,
    required this.onCenter,
    required this.onReport,
  });

  final VoidCallback onLegend;
  final VoidCallback onCenter;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final rl = context.rl;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const OsmCredit(),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              MapIconButton(
                icon: Icons.layers_outlined,
                tooltip: 'Qué significan los colores',
                onPressed: onLegend,
              ),
              const SizedBox(height: 10),
              MapIconButton(
                icon: Icons.my_location,
                tooltip: 'Centrar en mi ubicación',
                color: rl.primary,
                onPressed: onCenter,
              ),
              const SizedBox(height: 12),
              Semantics(
                button: true,
                label: 'Reportar peligro',
                excludeSemantics: true,
                child: Material(
                  color: AppTheme.hazard,
                  shape: const StadiumBorder(),
                  elevation: 4,
                  shadowColor: Colors.black45,
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: onReport,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.white, size: 22),
                          SizedBox(width: 8),
                          Text('Reportar peligro',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NearbySheet extends StatelessWidget {
  const _NearbySheet({
    required this.scroll,
    required this.app,
    required this.places,
    required this.hazards,
    required this.showHazards,
    required this.title,
    required this.subtitle,
    required this.onTab,
    required this.onListen,
    required this.onPlace,
    required this.onHazard,
  });

  final ScrollController scroll;
  final AppState app;
  final List<Place> places;
  final List<Report> hazards;
  final bool showHazards;
  final String title;
  final String subtitle;
  final ValueChanged<bool> onTab;
  final VoidCallback onListen;
  final ValueChanged<Place> onPlace;
  final ValueChanged<Report> onHazard;

  @override
  Widget build(BuildContext context) {
    final rl = context.rl;
    final text = Theme.of(context).textTheme;
    final me = app.me;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final List<Widget> items;
    if (showHazards) {
      items = hazards.isEmpty
          ? [
              const EmptyNote('No hay peligros reportados cerca.',
                  icon: Icons.verified_outlined)
            ]
          : [
              for (final r in hazards)
                HazardRow(
                  report: r,
                  me: me,
                  heading: app.heading,
                  onTap: () => onHazard(r),
                ),
            ];
    } else {
      items = places.isEmpty
          ? [
              EmptyNote(app.loadingPlaces
                  ? 'Descargando lugares…'
                  : 'No encontré lugares con ese filtro.')
            ]
          : [
              for (final p in places)
                PlaceRow(
                  place: p,
                  me: me,
                  heading: app.heading,
                  onTap: () => onPlace(p),
                ),
            ];
    }

    return Semantics(
      container: true,
      label: title,
      child: Container(
        decoration: BoxDecoration(
          color: rl.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: const [
            BoxShadow(color: Color(0x24000000), blurRadius: 20, offset: Offset(0, -4)),
          ],
        ),
        child: ListView(
          controller: scroll,
          padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottomInset),
          children: [
            const SheetHandle(),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(title, style: text.headlineSmall),
                      ),
                      if (subtitle.isNotEmpty)
                        Text(subtitle,
                            style: TextStyle(fontSize: 15, color: rl.text2)),
                    ],
                  ),
                ),
                ListenButton(onPressed: onListen, label: 'Escuchar'),
              ],
            ),
            const SizedBox(height: 14),
            Segmented<bool>(
              values: const [false, true],
              selected: showHazards,
              labelOf: (h) => h ? 'Peligros · ${hazards.length}' : 'Lugares',
              onChanged: onTab,
            ),
            if (me == null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Sin ubicación todavía: las distancias se miden desde el '
                  'centro de la zona piloto.',
                  style: TextStyle(fontSize: 14, color: rl.text2),
                ),
              ),
            const SizedBox(height: 4),
            ...items,
          ],
        ),
      ),
    );
  }
}
