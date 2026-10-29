import 'package:latlong2/latlong.dart';

import '../models/route_result.dart';
import '../models/settings.dart';
import 'geo.dart';

/// Lado del cuadro que se evita alrededor de cada peligro reportado.
const hazardBoxMeters = 30.0;

/// Peligros más cerca que esto del origen o destino no se envían:
/// openrouteservice rechaza la ruta si el origen cae dentro de una zona a evitar.
const _endpointClearance = 25.0;

/// Cuerpo JSON de la petición a openrouteservice.
///
/// Coordenadas en orden [lon, lat], como pide GeoJSON.
Map<String, Object?> buildRouteRequest({
  required LatLng start,
  required LatLng end,
  required MobilityProfile profile,
  required List<LatLng> hazards,
}) {
  final options = <String, Object?>{};
  if (profile.avoidSteps) options['avoid_features'] = ['steps'];
  if (profile == MobilityProfile.wheelchair) {
    options['profile_params'] = {
      'restrictions': {
        'maximum_incline': 6,
        'maximum_sloped_kerb': 0.06,
        'smoothness_type': 'good',
      },
    };
  }

  final usable = hazards
      .where((h) =>
          distanceMeters(h, start) > _endpointClearance &&
          distanceMeters(h, end) > _endpointClearance)
      .toList();
  if (usable.isNotEmpty) {
    options['avoid_polygons'] = {
      'type': 'MultiPolygon',
      'coordinates': [
        for (final h in usable) [squareRing(h, hazardBoxMeters)],
      ],
    };
  }

  return {
    'coordinates': [
      [start.longitude, start.latitude],
      [end.longitude, end.latitude],
    ],
    'language': 'es',
    'instructions': true,
    'units': 'm',
    if (options.isNotEmpty) 'options': options,
  };
}

/// Cuántos peligros se mandaron a evitar en [request].
int avoidedCount(Map<String, Object?> request) {
  final options = request['options'] as Map<String, Object?>?;
  final polygons = options?['avoid_polygons'] as Map<String, Object?>?;
  return (polygons?['coordinates'] as List?)?.length ?? 0;
}

/// Lee la respuesta GeoJSON de openrouteservice.
RouteResult parseRouteResponse(
  Map<String, Object?> json, {
  required String destinationName,
  int avoidedHazards = 0,
}) {
  final features = (json['features'] as List?) ?? const [];
  if (features.isEmpty) throw const FormatException('Respuesta sin ruta');
  final feature = (features.first as Map).cast<String, Object?>();

  final geometry = (feature['geometry'] as Map).cast<String, Object?>();
  final coords = (geometry['coordinates'] as List)
      .map((c) => c as List)
      .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
      .toList(growable: false);

  final props = (feature['properties'] as Map).cast<String, Object?>();
  final summary = ((props['summary'] as Map?) ?? const {}).cast<String, Object?>();
  final steps = <RouteStep>[];
  for (final seg in (props['segments'] as List?) ?? const []) {
    for (final s in ((seg as Map)['steps'] as List?) ?? const []) {
      final step = (s as Map).cast<String, Object?>();
      steps.add(RouteStep(
        instruction: (step['instruction'] as String?) ?? '',
        distanceMeters: (step['distance'] as num?)?.toDouble() ?? 0,
        type: (step['type'] as num?)?.toInt() ?? -1,
      ));
    }
  }

  return RouteResult(
    destinationName: destinationName,
    points: coords,
    distanceMeters: (summary['distance'] as num?)?.toDouble() ?? 0,
    durationSeconds: (summary['duration'] as num?)?.toDouble() ?? 0,
    steps: steps,
    avoidedHazards: avoidedHazards,
  );
}

/// "Gira a la derecha. Sigue 80 metros."
String spokenStep(RouteStep step) {
  final text = step.instruction.trim();
  if (step.type == 10 || step.distanceMeters < 5) return text;
  return '$text. Sigue ${formatDistance(step.distanceMeters)}.';
}

/// Resumen hablado de la ruta.
String spokenSummary(RouteResult route) {
  final minutes = (route.durationSeconds / 60).ceil();
  final avoided = route.avoidedHazards == 0
      ? ''
      : ' Evita ${route.avoidedHazards} '
          '${route.avoidedHazards == 1 ? 'peligro reportado' : 'peligros reportados'}.';
  final time = minutes <= 1 ? 'un minuto' : 'unos $minutes minutos';
  return 'Ruta a ${route.destinationName}: ${formatDistance(route.distanceMeters)}, '
      '$time caminando.$avoided';
}
