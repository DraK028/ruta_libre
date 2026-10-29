import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ruta_libre/core/route_api.dart';
import 'package:ruta_libre/models/route_result.dart';
import 'package:ruta_libre/models/settings.dart';

void main() {
  const start = LatLng(19.3958, -99.0912);
  const end = LatLng(19.3990, -99.0880);
  const midHazard = LatLng(19.3974, -99.0896);
  const hazardAtStart = LatLng(19.39585, -99.0912); // ~6 m del origen

  group('petición', () {
    test('coordenadas en orden [lon, lat] e idioma español', () {
      final body = buildRouteRequest(
          start: start, end: end, profile: MobilityProfile.blind, hazards: []);
      expect(body['coordinates'], [
        [-99.0912, 19.3958],
        [-99.0880, 19.3990],
      ]);
      expect(body['language'], 'es');
      expect(body['instructions'], isTrue);
      expect(body.containsKey('options'), isFalse);
    });

    test('silla de ruedas: evita escalones y limita pendiente', () {
      final body = buildRouteRequest(
          start: start,
          end: end,
          profile: MobilityProfile.wheelchair,
          hazards: []);
      final options = body['options'] as Map<String, Object?>;
      expect(options['avoid_features'], ['steps']);
      final restrictions = (options['profile_params'] as Map)['restrictions'] as Map;
      expect(restrictions['maximum_incline'], 6);
      expect(restrictions['maximum_sloped_kerb'], 0.06);
    });

    test('los peligros se envían como zonas a evitar, salvo junto al origen', () {
      final body = buildRouteRequest(
          start: start,
          end: end,
          profile: MobilityProfile.mobilityAid,
          hazards: [midHazard, hazardAtStart]);
      final polygons =
          (body['options'] as Map<String, Object?>)['avoid_polygons'] as Map;
      expect(polygons['type'], 'MultiPolygon');
      expect((polygons['coordinates'] as List), hasLength(1));
      expect(avoidedCount(body), 1);
    });
  });

  group('respuesta', () {
    final sample = <String, Object?>{
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              [-99.0912, 19.3958],
              [-99.0900, 19.3970],
              [-99.0880, 19.3990],
            ],
          },
          'properties': {
            'summary': {'distance': 480.4, 'duration': 345.9},
            'segments': [
              {
                'distance': 480.4,
                'duration': 345.9,
                'steps': [
                  {'instruction': 'Camina hacia el norte', 'distance': 200.0, 'type': 11},
                  {'instruction': 'Gira a la derecha', 'distance': 280.4, 'type': 1},
                  {'instruction': 'Llegaste a tu destino', 'distance': 0.0, 'type': 10},
                ],
              },
            ],
          },
        },
      ],
    };

    test('lee geometría [lon, lat], resumen y pasos', () {
      final r = parseRouteResponse(sample, destinationName: 'Farmacia');
      expect(r.points.first, start);
      expect(r.points, hasLength(3));
      expect(r.distanceMeters, 480.4);
      expect(r.steps.map((s) => s.type), [11, 1, 10]);
    });

    test('sin ruta lanza error', () {
      expect(() => parseRouteResponse({'features': []}, destinationName: 'x'),
          throwsFormatException);
    });

    test('resumen e indicaciones habladas', () {
      final r = parseRouteResponse(sample,
          destinationName: 'Farmacia', avoidedHazards: 2);
      expect(spokenSummary(r),
          'Ruta a Farmacia: 480 metros, unos 6 minutos caminando. '
          'Evita 2 peligros reportados.');
      expect(spokenStep(r.steps[1]), 'Gira a la derecha. Sigue 280 metros.');
      expect(spokenStep(r.steps[2]), 'Llegaste a tu destino');
    });

    test('un minuto en singular', () {
      const r = RouteResult(
        destinationName: 'Banco',
        points: [],
        distanceMeters: 50,
        durationSeconds: 40,
        steps: [],
        avoidedHazards: 0,
      );
      expect(spokenSummary(r), 'Ruta a Banco: 50 metros, un minuto caminando.');
    });
  });
}
