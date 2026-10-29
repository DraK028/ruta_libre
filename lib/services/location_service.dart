import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Posición y rumbo de la persona.
///
/// El rumbo sale del GPS mientras camina (no hay brújula); quieta, se
/// usan puntos cardinales en las indicaciones.
class LocationService {
  final ValueNotifier<LatLng?> position = ValueNotifier(null);

  /// Precisión de la última lectura en metros.
  double? accuracy;

  /// Hacia dónde camina, en grados; null si está quieta o no se sabe.
  double? heading;

  StreamSubscription<Position>? _sub;

  /// Por debajo de esta velocidad (m/s) el rumbo del GPS no es confiable.
  static const _minWalkingSpeed = 0.5;

  /// Pide permiso y empieza a seguir la ubicación. Devuelve un mensaje
  /// para el usuario si no se puede.
  Future<String?> start() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'La ubicación del teléfono está apagada.';
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return 'Ruta Libre necesita tu ubicación para mostrar qué hay cerca.';
    }

    await _sub?.cancel();
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 3,
      ),
    ).listen(_onPosition, onError: (Object _) {});
    return null;
  }

  void _onPosition(Position p) {
    accuracy = p.accuracy;
    final moving = p.speed >= _minWalkingSpeed && p.heading >= 0;
    heading = moving ? p.heading : null;
    position.value = LatLng(p.latitude, p.longitude);
  }

  void dispose() {
    _sub?.cancel();
    position.dispose();
  }
}
