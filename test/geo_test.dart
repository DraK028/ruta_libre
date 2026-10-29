import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ruta_libre/core/geo.dart';

void main() {
  const origin = LatLng(19.3958, -99.0912);
  // ~111 m al norte y ~105 m al este de origin.
  const north = LatLng(19.3968, -99.0912);
  const east = LatLng(19.3958, -99.0902);

  test('distancia de haversine', () {
    expect(distanceMeters(origin, north), closeTo(111.2, 1));
    expect(distanceMeters(origin, east), closeTo(104.9, 1));
    expect(distanceMeters(origin, origin), 0);
  });

  test('rumbo', () {
    expect(bearingDegrees(origin, north), closeTo(0, 0.5));
    expect(bearingDegrees(origin, east), closeTo(90, 0.5));
    expect(bearingDegrees(north, origin), closeTo(180, 0.5));
  });

  test('punto cardinal', () {
    expect(cardinalDirection(0), 'al norte');
    expect(cardinalDirection(350), 'al norte');
    expect(cardinalDirection(44), 'al noreste');
    expect(cardinalDirection(90), 'al este');
    expect(cardinalDirection(225), 'al suroeste');
  });

  test('dirección relativa a hacia dónde camina', () {
    expect(relativeDirection(0, 0), 'al frente');
    expect(relativeDirection(90, 0), 'a tu derecha');
    expect(relativeDirection(270, 0), 'a tu izquierda');
    expect(relativeDirection(45, 0), 'adelante a la derecha');
    expect(relativeDirection(180, 0), 'atrás');
    // Cruza el 0: camina al noroeste (350) y el destino está al noreste (30).
    expect(relativeDirection(30, 350), 'adelante a la derecha');
    expect(relativeDirection(200, 10), 'atrás');
  });

  test('sin rumbo usa puntos cardinales', () {
    expect(directionFrom(origin, north, null), 'al norte');
    expect(directionFrom(origin, north, 90), 'a tu izquierda');
  });

  test('distancias redondeadas para voz', () {
    expect(formatDistance(4), 'menos de 10 metros');
    expect(formatDistance(42), '40 metros');
    expect(formatDistance(48), '50 metros');
    expect(formatDistance(234), '230 metros');
    expect(formatDistance(1000), '1 kilómetro');
    expect(formatDistance(1260), '1.3 kilómetros');
  });

  test('cuadro alrededor de un peligro es un anillo cerrado de ~30 m', () {
    final ring = squareRing(origin, 30);
    expect(ring.length, 5);
    expect(ring.first, ring.last);
    final sw = LatLng(ring[0][1], ring[0][0]);
    final se = LatLng(ring[1][1], ring[1][0]);
    final ne = LatLng(ring[2][1], ring[2][0]);
    expect(distanceMeters(sw, se), closeTo(30, 0.5));
    expect(distanceMeters(se, ne), closeTo(30, 0.5));
  });
}
