import 'package:latlong2/latlong.dart';

/// Un paso de la ruta ("Gira a la derecha en Av. Té").
class RouteStep {
  const RouteStep({
    required this.instruction,
    required this.distanceMeters,
    required this.type,
  });

  final String instruction;
  final double distanceMeters;

  /// Código de openrouteservice (0 izquierda, 1 derecha, 6 recto, 10 llegada…).
  final int type;
}

/// Ruta calculada hacia un destino.
class RouteResult {
  const RouteResult({
    required this.destinationName,
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.steps,
    required this.avoidedHazards,
  });

  final String destinationName;
  final List<LatLng> points;
  final double distanceMeters;
  final double durationSeconds;
  final List<RouteStep> steps;

  /// Cuántos peligros reportados se pidió evitar.
  final int avoidedHazards;
}
