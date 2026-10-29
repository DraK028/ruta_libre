import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../core/osm_parser.dart';
import '../models/place.dart';

class PlacesException implements Exception {
  const PlacesException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Descarga lugares de OpenStreetMap por zona y los guarda en el teléfono.
///
/// La API pública de Overpass no debe usarse como backend de una app, así
/// que cada zona se descarga una sola vez y se reutiliza por
/// [AppConfig.placesCacheTtl].
class PlacesService {
  PlacesService(this._prefs, {http.Client? client})
      : _client = client ?? http.Client();

  final SharedPreferences _prefs;
  final http.Client _client;

  /// Zona redondeada a ~100 m para que pequeños cambios usen la misma caché.
  String _zoneKey(LatLng c, int r) =>
      'zone_${c.latitude.toStringAsFixed(3)}_${c.longitude.toStringAsFixed(3)}_$r';

  /// Lugares guardados de la zona, aunque estén vencidos (null si no hay).
  List<Place>? cached(LatLng center, int radius) {
    final raw = _prefs.getString(_zoneKey(center, radius));
    if (raw == null) return null;
    final json = (jsonDecode(raw) as Map).cast<String, Object?>();
    return (json['places'] as List)
        .map((e) => Place.fromJson((e as Map).cast<String, Object?>()))
        .toList();
  }

  bool isFresh(LatLng center, int radius) {
    final raw = _prefs.getString(_zoneKey(center, radius));
    if (raw == null) return false;
    final json = (jsonDecode(raw) as Map).cast<String, Object?>();
    final saved = DateTime.parse(json['savedAt'] as String);
    return DateTime.now().difference(saved) < AppConfig.placesCacheTtl;
  }

  /// Lugares de la zona: de la caché si está vigente; si no, de Overpass.
  Future<List<Place>> load(
    LatLng center, {
    int radius = AppConfig.pilotRadiusMeters,
    bool force = false,
  }) async {
    if (!force && isFresh(center, radius)) return cached(center, radius)!;
    try {
      final places = await _download(center, radius);
      await _prefs.setString(
        _zoneKey(center, radius),
        jsonEncode({
          'savedAt': DateTime.now().toIso8601String(),
          'places': places.map((p) => p.toJson()).toList(),
        }),
      );
      return places;
    } on PlacesException {
      // Sin red o servidor ocupado: mejor datos viejos que nada.
      final old = cached(center, radius);
      if (old != null) return old;
      rethrow;
    }
  }

  Future<List<Place>> _download(LatLng center, int radius) async {
    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse(AppConfig.overpassUrl),
            headers: kIsWeb ? null : {'User-Agent': AppConfig.userAgent},
            body: {'data': buildOverpassQuery(center, radius)},
          )
          .timeout(const Duration(seconds: 40));
    } on Exception {
      throw const PlacesException(
          'No hay conexión para descargar los lugares de esta zona.');
    }
    if (res.statusCode == 429 || res.statusCode == 504) {
      throw const PlacesException(
          'El servidor de OpenStreetMap está ocupado. Intenta en un minuto.');
    }
    if (res.statusCode != 200) {
      throw PlacesException(
          'No se pudieron descargar los lugares (error ${res.statusCode}).');
    }
    final json = (jsonDecode(utf8.decode(res.bodyBytes)) as Map)
        .cast<String, Object?>();
    return parseOverpass(json);
  }
}
