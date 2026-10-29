import 'package:latlong2/latlong.dart';

import '../models/place.dart';

/// Consulta de Overpass: lugares con dato de accesibilidad, servicios
/// importantes, paradas y cruces con información de rampa o guía podotáctil.
String buildOverpassQuery(LatLng center, int radiusMeters) {
  final around = '(around:$radiusMeters,${center.latitude},${center.longitude})';
  return '''
[out:json][timeout:25];
(
  nwr["wheelchair"]$around;
  nwr["amenity"~"^(pharmacy|hospital|clinic|doctors|dentist|bank|atm|restaurant|cafe|fast_food|toilets|school|college|university|police|post_office|marketplace|townhall|library|place_of_worship)\$"]$around;
  nwr["shop"~"^(supermarket|convenience|chemist|bakery|mall|department_store)\$"]$around;
  node["highway"~"^(bus_stop|elevator)\$"]$around;
  nwr["railway"="station"]$around;
  node["kerb"]$around;
  node["tactile_paving"]$around;
);
out center tags;
''';
}

const _amenity = {
  'pharmacy': 'Farmacia',
  'hospital': 'Hospital',
  'clinic': 'Clínica',
  'doctors': 'Consultorio',
  'dentist': 'Dentista',
  'bank': 'Banco',
  'atm': 'Cajero',
  'restaurant': 'Restaurante',
  'cafe': 'Cafetería',
  'fast_food': 'Comida rápida',
  'toilets': 'Baños públicos',
  'school': 'Escuela',
  'college': 'Escuela',
  'university': 'Universidad',
  'police': 'Policía',
  'post_office': 'Correos',
  'marketplace': 'Mercado',
  'townhall': 'Oficina de gobierno',
  'library': 'Biblioteca',
  'place_of_worship': 'Templo',
};

const _shop = {
  'supermarket': 'Supermercado',
  'convenience': 'Tienda',
  'chemist': 'Farmacia',
  'bakery': 'Panadería',
  'mall': 'Centro comercial',
  'department_store': 'Tienda departamental',
};

/// Nombre de categoría en español a partir de las etiquetas.
String categoryFor(Map<String, String> tags) {
  final amenity = _amenity[tags['amenity']];
  if (amenity != null) return amenity;
  final shop = _shop[tags['shop']];
  if (shop != null) return shop;
  if (tags.containsKey('shop')) return 'Comercio';
  if (tags['highway'] == 'bus_stop') return 'Parada de autobús';
  if (tags['highway'] == 'elevator') return 'Elevador';
  if (tags['railway'] == 'station' || tags['public_transport'] == 'station') {
    return 'Estación';
  }
  if (_isCrossing(tags)) return 'Cruce peatonal';
  if (tags.containsKey('building')) return 'Edificio';
  return 'Lugar';
}

bool _isCrossing(Map<String, String> tags) =>
    tags.containsKey('kerb') ||
    tags['highway'] == 'crossing' ||
    tags['footway'] == 'crossing' ||
    (tags.containsKey('tactile_paving') && !tags.containsKey('name'));

/// Accesibilidad de un cruce según su borde de banqueta (`kerb`).
Accessibility _crossingAccess(Map<String, String> tags) {
  final explicit = tags['wheelchair'];
  if (explicit != null) return Accessibility.fromTag(explicit);
  return switch (tags['kerb']) {
    'flush' || 'no' => Accessibility.yes,
    'lowered' => Accessibility.yes,
    'rolled' => Accessibility.limited,
    'raised' || 'yes' => Accessibility.no,
    _ => Accessibility.unknown,
  };
}

bool? _yesNo(String? value) => switch (value) {
      'yes' || 'designated' => true,
      'no' => false,
      _ => null,
    };

/// Convierte la respuesta JSON de Overpass en lugares.
///
/// Ignora elementos sin coordenadas y los que no aportan nada al usuario
/// (sin nombre, sin categoría útil y sin dato de accesibilidad).
List<Place> parseOverpass(Map<String, Object?> json) {
  final elements = (json['elements'] as List?) ?? const [];
  final places = <Place>[];

  for (final raw in elements) {
    final e = (raw as Map).cast<String, Object?>();
    final tags = ((e['tags'] as Map?) ?? const {}).cast<String, String>();
    if (tags.isEmpty) continue;

    final center = (e['center'] as Map?)?.cast<String, Object?>();
    final lat = (e['lat'] ?? center?['lat']) as num?;
    final lon = (e['lon'] ?? center?['lon']) as num?;
    if (lat == null || lon == null) continue;

    final crossing = _isCrossing(tags) && !tags.containsKey('name');
    final category = categoryFor(tags);
    final access =
        crossing ? _crossingAccess(tags) : Accessibility.fromTag(tags['wheelchair']);
    final name = tags['name']?.trim();

    if ((name == null || name.isEmpty) &&
        category == 'Lugar' &&
        access == Accessibility.unknown) {
      continue;
    }

    places.add(Place(
      osmType: (e['type'] as String?) ?? 'node',
      osmId: (e['id'] as num).toInt(),
      name: (name == null || name.isEmpty) ? category : name,
      category: category,
      location: LatLng(lat.toDouble(), lon.toDouble()),
      kind: crossing ? PlaceKind.crossing : PlaceKind.poi,
      access: access,
      accessibleToilet: _yesNo(tags['toilets:wheelchair']),
      tactilePaving: _yesNo(tags['tactile_paving']),
      description: tags['wheelchair:description'],
    ));
  }
  return places;
}
