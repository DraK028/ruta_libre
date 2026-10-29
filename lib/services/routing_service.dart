import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../core/route_api.dart';
import '../models/route_result.dart';
import '../models/settings.dart';

class RoutingException implements Exception {
  const RoutingException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Pide rutas a pie o en silla de ruedas a openrouteservice.
class RoutingService {
  RoutingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<RouteResult> route({
    required String apiKey,
    required LatLng start,
    required LatLng end,
    required String destinationName,
    required MobilityProfile profile,
    required List<LatLng> hazards,
  }) async {
    if (apiKey.trim().isEmpty) {
      throw const RoutingException(
          'Falta la clave de openrouteservice. Agrégala en Ajustes, '
          'en la sección Rutas.');
    }

    final body = buildRouteRequest(
      start: start,
      end: end,
      profile: profile,
      hazards: hazards,
    );

    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse('${AppConfig.orsBaseUrl}/${profile.orsProfile}/geojson'),
            headers: {
              'Authorization': apiKey.trim(),
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/geo+json, application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 25));
    } on Exception {
      throw const RoutingException('No hay conexión para calcular la ruta.');
    }

    final json = _decode(res);
    if (res.statusCode == 200) {
      try {
        return parseRouteResponse(
          json,
          destinationName: destinationName,
          avoidedHazards: avoidedCount(body),
        );
      } on Object {
        throw const RoutingException('La respuesta de la ruta no se pudo leer.');
      }
    }
    if (res.statusCode == 429) {
      throw const RoutingException(
          'Se alcanzó el límite de rutas por ahora. Intenta en un minuto.');
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw const RoutingException('La clave de openrouteservice no es válida.');
    }
    final message = ((json['error'] as Map?)?['message'] as String?) ?? '';
    throw RoutingException(message.isEmpty
        ? 'No se encontró una ruta accesible hasta ese lugar.'
        : 'No se encontró una ruta accesible ($message).');
  }

  Map<String, Object?> _decode(http.Response res) {
    try {
      return (jsonDecode(utf8.decode(res.bodyBytes)) as Map)
          .cast<String, Object?>();
    } on FormatException {
      return const {};
    }
  }
}
