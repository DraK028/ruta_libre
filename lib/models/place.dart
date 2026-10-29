import 'package:latlong2/latlong.dart';

/// Qué tan accesible es un lugar para silla de ruedas, según OSM.
enum Accessibility {
  /// `wheelchair=yes` o `designated`: entrada y áreas principales sin escalón.
  yes('Accesible', 'entrada sin escalón'),

  /// `wheelchair=limited`: escalón de hasta 7 cm o acceso parcial.
  limited('Acceso limitado', 'escalón pequeño o acceso parcial'),

  /// `wheelchair=no`: escalón mayor a 7 cm o áreas principales no accesibles.
  no('No accesible', 'tiene escalones o áreas sin acceso'),

  /// Sin etiqueta: nadie lo ha registrado todavía.
  unknown('Sin dato', 'nadie ha registrado su accesibilidad');

  const Accessibility(this.label, this.explanation);
  final String label;
  final String explanation;

  static Accessibility fromTag(String? value) => switch (value) {
        'yes' || 'designated' => Accessibility.yes,
        'limited' => Accessibility.limited,
        'no' => Accessibility.no,
        _ => Accessibility.unknown,
      };
}

/// Tipo de elemento en el mapa.
enum PlaceKind {
  /// Comercio, servicio o edificio.
  poi,

  /// Cruce o borde de banqueta (`kerb`, `tactile_paving`).
  crossing,
}

/// Un lugar de OpenStreetMap con sus datos de accesibilidad.
class Place {
  const Place({
    required this.osmType,
    required this.osmId,
    required this.name,
    required this.category,
    required this.location,
    required this.kind,
    this.access = Accessibility.unknown,
    this.accessibleToilet,
    this.tactilePaving,
    this.description,
  });

  /// `node`, `way` o `relation`.
  final String osmType;
  final int osmId;
  final String name;
  final String category;
  final LatLng location;
  final PlaceKind kind;
  final Accessibility access;

  /// `toilets:wheelchair`. Null si no hay dato.
  final bool? accessibleToilet;

  /// `tactile_paving`. Null si no hay dato.
  final bool? tactilePaving;

  /// `wheelchair:description`.
  final String? description;

  String get key => '$osmType/$osmId';

  Uri get osmUrl => Uri.parse('https://www.openstreetmap.org/$osmType/$osmId');

  Map<String, Object?> toJson() => {
        'osmType': osmType,
        'osmId': osmId,
        'name': name,
        'category': category,
        'lat': location.latitude,
        'lon': location.longitude,
        'kind': kind.name,
        'access': access.name,
        'accessibleToilet': accessibleToilet,
        'tactilePaving': tactilePaving,
        'description': description,
      };

  factory Place.fromJson(Map<String, Object?> json) => Place(
        osmType: json['osmType'] as String,
        osmId: json['osmId'] as int,
        name: json['name'] as String,
        category: json['category'] as String,
        location: LatLng(
          (json['lat'] as num).toDouble(),
          (json['lon'] as num).toDouble(),
        ),
        kind: PlaceKind.values.byName(json['kind'] as String),
        access: Accessibility.values.byName(json['access'] as String),
        accessibleToilet: json['accessibleToilet'] as bool?,
        tactilePaving: json['tactilePaving'] as bool?,
        description: json['description'] as String?,
      );
}
