import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';
import 'core/describe.dart';
import 'core/geo.dart';
import 'core/hazard_alerts.dart';
import 'models/place.dart';
import 'models/report.dart';
import 'models/route_result.dart';
import 'models/settings.dart';
import 'services/location_service.dart';
import 'services/places_service.dart';
import 'services/report_repository.dart';
import 'services/routing_service.dart';
import 'services/voice_service.dart';

/// Estado de la app y acceso a los servicios.
///
/// Las pantallas solo hablan con esta clase; cada servicio sigue siendo
/// independiente y reemplazable.
class AppState extends ChangeNotifier {
  AppState({
    required SharedPreferences prefs,
    required this.voice,
    required this.location,
    required this.places,
    required this.reportsRepo,
    required this.routing,
  })  : _prefs = prefs,
        _settings = _loadSettings(prefs) {
    voice.guidanceEnabled = _settings.voiceGuidance;
    location.position.addListener(_onMove);
  }

  static const _kSettings = 'settings';
  static const _kFeedback = 'place_feedback';

  final SharedPreferences _prefs;
  final VoiceService voice;
  final LocationService location;
  final PlacesService places;
  final ReportRepository reportsRepo;
  final RoutingService routing;

  AppSettings _settings;
  List<Place> _places = [];
  List<Report> _reports = [];
  RouteResult? _route;
  bool _loadingPlaces = false;
  String? _placesError;
  final Map<String, DateTime> _lastAlerted = {};

  AppSettings get settings => _settings;
  MobilityProfile get profile => _settings.profile ?? MobilityProfile.mobilityAid;
  List<Place> get allPlaces => List.unmodifiable(_places);
  RouteResult? get route => _route;
  bool get loadingPlaces => _loadingPlaces;
  String? get placesError => _placesError;
  LatLng? get me => location.position.value;
  double? get heading => location.heading;

  /// Lugares que se muestran según el filtro "solo accesibles".
  List<Place> get visiblePlaces => _settings.onlyAccessible
      ? _places
          .where((p) =>
              p.access == Accessibility.yes || p.access == Accessibility.limited)
          .toList()
      : allPlaces;

  List<Report> activeReports([DateTime? now]) {
    final t = now ?? DateTime.now();
    return _reports.where((r) => r.isActive(t)).toList();
  }

  // ---------- Arranque ----------

  Future<void> init() async {
    await voice.init(speechRate: _settings.speechRate);
    _reports = await reportsRepo.loadAll();
    final cached = places.cached(AppConfig.pilotCenter, AppConfig.pilotRadiusMeters);
    if (cached != null) _places = cached;
    notifyListeners();
  }

  /// Empieza a seguir la ubicación y descarga la zona piloto.
  /// Devuelve un mensaje para el usuario si algo falla.
  Future<String?> start() async {
    final locationError = await location.start();
    await loadPlaces(AppConfig.pilotCenter);
    return locationError ?? _placesError;
  }

  // ---------- Ajustes ----------

  static AppSettings _loadSettings(SharedPreferences prefs) {
    final raw = prefs.getString(_kSettings);
    if (raw == null) return const AppSettings();
    return AppSettings.fromJson((jsonDecode(raw) as Map).cast<String, Object?>());
  }

  Future<void> updateSettings(AppSettings next) async {
    _settings = next;
    voice.guidanceEnabled = next.voiceGuidance;
    await voice.setSpeechRate(next.speechRate);
    await _prefs.setString(_kSettings, jsonEncode(next.toJson()));
    notifyListeners();
  }

  /// Primera elección del perfil: también fija los valores por defecto.
  Future<void> chooseProfile(MobilityProfile p) => updateSettings(
        _settings.copyWith(
          profile: p,
          voiceGuidance: p.voiceByDefault || _settings.voiceGuidance,
          onlyAccessible: p.onlyAccessibleByDefault,
        ),
      );

  // ---------- Lugares ----------

  Future<void> loadPlaces(LatLng center, {bool force = false}) async {
    _loadingPlaces = true;
    _placesError = null;
    notifyListeners();
    try {
      final fresh = await places.load(center, force: force);
      // Une con lo que ya había (otra zona) sin duplicar.
      final byKey = {for (final p in _places) p.key: p};
      for (final p in fresh) {
        byKey[p.key] = p;
      }
      _places = byKey.values.toList();
    } on PlacesException catch (e) {
      _placesError = e.message;
    } finally {
      _loadingPlaces = false;
      notifyListeners();
    }
  }

  /// Lugares y peligros ordenados por distancia (para la lista hablada).
  List<Place> placesNearby({int limit = 30, bool includeCrossings = false}) {
    final here = me ?? AppConfig.pilotCenter;
    final list = visiblePlaces
        .where((p) => includeCrossings || p.kind == PlaceKind.poi)
        .toList()
      ..sort((a, b) => distanceMeters(here, a.location)
          .compareTo(distanceMeters(here, b.location)));
    return list.take(limit).toList();
  }

  List<Report> reportsNearby() {
    final here = me ?? AppConfig.pilotCenter;
    return activeReports()
      ..sort((a, b) => distanceMeters(here, a.location)
          .compareTo(distanceMeters(here, b.location)));
  }

  /// "¿Es correcto?" — se guarda para enviarlo a OSM como nota en el piloto.
  Future<void> saveFeedback(Place p, {required bool correct}) async {
    final list = _prefs.getStringList(_kFeedback) ?? [];
    list.add(jsonEncode({
      'place': p.key,
      'access': p.access.name,
      'correct': correct,
      'at': DateTime.now().toIso8601String(),
    }));
    await _prefs.setStringList(_kFeedback, list);
  }

  // ---------- Reportes ----------

  Future<Report> addReport({
    required ReportType type,
    required Severity severity,
    required LatLng at,
    String note = '',
    String? photoPath,
  }) async {
    final now = DateTime.now();
    final report = Report(
      id: '${now.microsecondsSinceEpoch}',
      type: type,
      severity: severity,
      location: at,
      createdAt: now,
      lastConfirmedAt: now,
      note: note,
      photoPath: photoPath,
    );
    await _saveReport(report);
    // Quien reporta ya sabe del peligro: no se le avisa al instante.
    _lastAlerted[report.id] = now;
    return report;
  }

  Future<Report> confirmReport(Report r) => _saveReport(r.confirm(DateTime.now()));

  Future<Report> voteGone(Report r) => _saveReport(r.voteGone());

  Report? reportById(String id) {
    for (final r in _reports) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<Report> _saveReport(Report r) async {
    await reportsRepo.save(r);
    final i = _reports.indexWhere((x) => x.id == r.id);
    if (i == -1) {
      _reports = [..._reports, r];
    } else {
      _reports = [..._reports]..[i] = r;
    }
    notifyListeners();
    return r;
  }

  // ---------- Rutas ----------

  /// La clave escrita en Ajustes tiene prioridad sobre la de compilación.
  String get routingKey => _settings.orsApiKey.trim().isNotEmpty
      ? _settings.orsApiKey.trim()
      : AppConfig.orsApiKey;

  bool get hasRoutingKey => routingKey.isNotEmpty;

  Future<RouteResult> routeTo(Place destination) async {
    final start = me;
    if (start == null) {
      throw const RoutingException('Aún no sé dónde estás. Revisa la ubicación.');
    }
    final result = await routing.route(
      apiKey: routingKey,
      start: start,
      end: destination.location,
      destinationName: destination.name,
      profile: profile,
      hazards: activeReports()
          .where((r) => r.severity != Severity.low)
          .map((r) => r.location)
          .toList(),
    );
    _route = result;
    notifyListeners();
    return result;
  }

  void clearRoute() {
    _route = null;
    notifyListeners();
  }

  // ---------- Avisos de peligro ----------

  void _onMove() {
    // El mapa y las distancias dependen de la posición: se redibujan.
    // El GPS solo avisa cada 3 m, así que no es una carga excesiva.
    notifyListeners();
    final here = me;
    if (here == null || !_settings.hazardAlerts) return;
    final now = DateTime.now();
    final due = hazardsToAnnounce(
      reports: _reports,
      me: here,
      now: now,
      lastAlerted: _lastAlerted,
      radiusMeters: AppConfig.hazardAlertMeters,
      cooldown: AppConfig.hazardAlertCooldown,
    );
    if (due.isEmpty) return;
    final nearest = due.first;
    for (final r in due) {
      _lastAlerted[r.id] = now;
    }
    HapticFeedback.heavyImpact();
    // El aviso de peligro se dice aunque la guía por voz esté apagada.
    voice.speak('Atención. ${describeReport(nearest, now, me: here, heading: heading)}');
  }

  @override
  void dispose() {
    location.position.removeListener(_onMove);
    location.dispose();
    voice.dispose();
    super.dispose();
  }
}

/// Acceso a [AppState] desde cualquier pantalla.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Sin redibujar al cambiar el estado (para callbacks e initState).
  static AppState read(BuildContext context) =>
      (context.getElementForInheritedWidgetOfExactType<AppScope>()!.widget
              as AppScope)
          .notifier!;
}
