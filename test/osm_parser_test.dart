import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ruta_libre/core/osm_parser.dart';
import 'package:ruta_libre/models/place.dart';

void main() {
  final sample = <String, Object?>{
    'elements': [
      {
        'type': 'node',
        'id': 1,
        'lat': 19.396,
        'lon': -99.091,
        'tags': {
          'amenity': 'pharmacy',
          'name': 'Farmacia Ejemplo',
          'wheelchair': 'yes',
          'toilets:wheelchair': 'no',
          'wheelchair:description': 'Rampa por la entrada lateral',
        },
      },
      {
        // Edificio como "way": las coordenadas vienen en "center".
        'type': 'way',
        'id': 2,
        'center': {'lat': 19.397, 'lon': -99.092},
        'tags': {'shop': 'supermarket', 'wheelchair': 'limited'},
      },
      {
        'type': 'node',
        'id': 3,
        'lat': 19.395,
        'lon': -99.090,
        'tags': {'kerb': 'lowered', 'tactile_paving': 'yes'},
      },
      {
        'type': 'node',
        'id': 4,
        'lat': 19.395,
        'lon': -99.089,
        'tags': {'kerb': 'raised'},
      },
      {
        // Sin nombre, sin categoría útil y sin dato: se descarta.
        'type': 'node',
        'id': 5,
        'lat': 19.395,
        'lon': -99.088,
        'tags': {'source': 'survey'},
      },
      {
        // Sin coordenadas: se descarta.
        'type': 'way',
        'id': 6,
        'tags': {'amenity': 'bank', 'name': 'Banco'},
      },
      {
        'type': 'node',
        'id': 7,
        'lat': 19.394,
        'lon': -99.087,
        'tags': {'amenity': 'bank', 'name': 'Banco Norte', 'wheelchair': 'designated'},
      },
    ],
  };

  test('convierte elementos de Overpass en lugares', () {
    final places = parseOverpass(sample);
    expect(places.map((p) => p.osmId), [1, 2, 3, 4, 7]);

    final pharmacy = places.first;
    expect(pharmacy.name, 'Farmacia Ejemplo');
    expect(pharmacy.category, 'Farmacia');
    expect(pharmacy.access, Accessibility.yes);
    expect(pharmacy.accessibleToilet, isFalse);
    expect(pharmacy.description, 'Rampa por la entrada lateral');
    expect(pharmacy.kind, PlaceKind.poi);
  });

  test('usa el centro de un way y la categoría como nombre si no tiene', () {
    final market = parseOverpass(sample)[1];
    expect(market.location, const LatLng(19.397, -99.092));
    expect(market.name, 'Supermercado');
    expect(market.access, Accessibility.limited);
    expect(market.key, 'way/2');
  });

  test('los cruces se califican por su borde de banqueta', () {
    final places = parseOverpass(sample);
    final lowered = places[2];
    final raised = places[3];
    expect(lowered.kind, PlaceKind.crossing);
    expect(lowered.access, Accessibility.yes);
    expect(lowered.tactilePaving, isTrue);
    expect(raised.access, Accessibility.no);
  });

  test('designated cuenta como accesible', () {
    expect(parseOverpass(sample).last.access, Accessibility.yes);
  });

  test('la consulta incluye el radio y el centro', () {
    final q = buildOverpassQuery(const LatLng(19.3958, -99.0912), 1000);
    expect(q, contains('around:1000,19.3958,-99.0912'));
    expect(q, contains('"wheelchair"'));
    expect(q, contains('out center tags;'));
  });

  test('Place sobrevive ida y vuelta por JSON', () {
    final p = parseOverpass(sample).first;
    final back = Place.fromJson(p.toJson());
    expect(back.key, p.key);
    expect(back.access, p.access);
    expect(back.accessibleToilet, p.accessibleToilet);
  });
}
