/// Cálculos geográficos sin dependencias de Flutter (fáciles de probar).
library;

import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

const _earthRadius = 6371000.0;

double _rad(double deg) => deg * math.pi / 180;
double _deg(double rad) => rad * 180 / math.pi;

/// Distancia en metros entre dos puntos (fórmula de haversine).
double distanceMeters(LatLng a, LatLng b) {
  final dLat = _rad(b.latitude - a.latitude);
  final dLon = _rad(b.longitude - a.longitude);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(a.latitude)) *
          math.cos(_rad(b.latitude)) *
          math.pow(math.sin(dLon / 2), 2);
  return 2 * _earthRadius * math.asin(math.sqrt(h));
}

/// Rumbo de a hacia b, en grados desde el norte (0 a 360).
double bearingDegrees(LatLng a, LatLng b) {
  final lat1 = _rad(a.latitude), lat2 = _rad(b.latitude);
  final dLon = _rad(b.longitude - a.longitude);
  final y = math.sin(dLon) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  return (_deg(math.atan2(y, x)) + 360) % 360;
}

/// Ángulo en (-180, 180]: negativo a la izquierda, positivo a la derecha.
double relativeAngle(double bearing, double heading) {
  var d = (bearing - heading) % 360;
  if (d > 180) d -= 360;
  if (d <= -180) d += 360;
  return d;
}

const _cardinals = [
  'al norte',
  'al noreste',
  'al este',
  'al sureste',
  'al sur',
  'al suroeste',
  'al oeste',
  'al noroeste',
];

/// "al norte", "al sureste"… para cuando no se conoce hacia dónde camina.
String cardinalDirection(double bearing) {
  final index = (((bearing % 360) + 22.5) ~/ 45) % 8;
  return _cardinals[index];
}

/// Dirección relativa a hacia dónde camina la persona.
String relativeDirection(double bearing, double heading) {
  final a = relativeAngle(bearing, heading);
  final abs = a.abs();
  if (abs <= 22.5) return 'al frente';
  if (abs >= 157.5) return 'atrás';
  final side = a > 0 ? 'derecha' : 'izquierda';
  if (abs <= 67.5) return 'adelante a la $side';
  if (abs < 112.5) return 'a tu $side';
  return 'atrás a la $side';
}

/// Dirección relativa si hay rumbo; si no, punto cardinal.
String directionFrom(LatLng from, LatLng to, double? heading) {
  final bearing = bearingDegrees(from, to);
  return heading == null
      ? cardinalDirection(bearing)
      : relativeDirection(bearing, heading);
}

/// Redondea para leer en voz alta: 5 m cerca, 10 m lejos, km a partir de 1 km.
String formatDistance(double meters) {
  if (meters < 10) return 'menos de 10 metros';
  if (meters < 100) return '${(meters / 5).round() * 5} metros';
  if (meters < 1000) return '${(meters / 10).round() * 10} metros';
  final km = (meters / 100).round() / 10;
  final text = km == km.roundToDouble()
      ? km.toStringAsFixed(0)
      : km.toStringAsFixed(1);
  return '$text ${km == 1 ? 'kilómetro' : 'kilómetros'}';
}

/// Cuadro de ~[meters] por lado alrededor de un punto, como anillo GeoJSON
/// ([lon, lat], cerrado). Sirve para pedir rutas que lo eviten.
List<List<double>> squareRing(LatLng center, double meters) {
  final dLat = meters / 2 / 111320;
  final dLon = meters / 2 / (111320 * math.cos(_rad(center.latitude)));
  final s = center.latitude - dLat, n = center.latitude + dLat;
  final w = center.longitude - dLon, e = center.longitude + dLon;
  return [
    [w, s],
    [e, s],
    [e, n],
    [w, n],
    [w, s],
  ];
}

/// Para leer en pantalla: "120 m", "1.2 km".
String formatDistanceShort(double meters) {
  if (meters < 1000) return '${(meters / 10).round() * 10} m';
  final km = (meters / 100).round() / 10;
  return '${km == km.roundToDouble() ? km.toStringAsFixed(0) : km.toStringAsFixed(1)} km';
}

/// Velocidad de paso tranquila (m/s) para estimar tiempos sin ruta.
const walkingSpeed = 1.0;

/// "2 min", "1 h 5 min". Nunca menos de 1 min.
String formatDuration(double seconds) {
  final minutes = (seconds / 60).ceil().clamp(1, 100000);
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}
