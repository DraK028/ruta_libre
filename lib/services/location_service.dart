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

  /// Si ya se está siguiendo la ubicación.
  bool get isRunning => _sub != null;

  /// Por debajo de esta velocidad (m/s) el rumbo del GPS no es confiable.
  static const _minWalkingSpeed = 0.5;

  /// En Android se puede seguir la ubicación con la pantalla apagada.
  static bool get supportsBackground =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Pide permiso y empieza a seguir la ubicación. Devuelve un mensaje
  /// para el usuario si no se puede.
  ///
  /// Con [background] en Android se inicia un servicio en primer plano
  /// (notificación fija): así la app sigue recibiendo la ubicación y avisando
  /// de peligros con el teléfono bloqueado.
  Future<String?> start({bool background = false}) async {
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

    // Una primera lectura rápida: la última conocida (instantánea, puede ser
    // vieja) y luego la actual. Así el mapa no espera a que llegue el flujo.
    unawaited(_quickFix());

    await _sub?.cancel();
    _sub = Geolocator.getPositionStream(
      locationSettings: _streamSettings(background),
    ).listen(_onPosition, onError: (Object _) {});
    return null;
  }

  /// Cada 3 m de movimiento; en Android, además, como máximo cada segundo.
  LocationSettings _streamSettings(bool background) {
    if (!supportsBackground) {
      return const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 3,
      );
    }
    return AndroidSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 3,
      intervalDuration: const Duration(seconds: 1),
      foregroundNotificationConfig: background
          ? const ForegroundNotificationConfig(
              notificationTitle: 'Ruta Libre está activa',
              notificationText:
                  'Usa tu ubicación para avisarte de peligros cercanos.',
              notificationChannelName: 'Ubicación en segundo plano',
              enableWakeLock: true,
              setOngoing: true,
            )
          : null,
    );
  }

  /// Deja de seguir la ubicación (y detiene la notificación fija).
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> _quickFix() async {
    if (!kIsWeb) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null && position.value == null) _onPosition(last);
      } catch (_) {}
    }
    try {
      final now = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      _onPosition(now);
    } catch (_) {
      // Sin lectura inmediata: el flujo la dará en cuanto la tenga.
    }
  }

  /// Espera la primera ubicación hasta [timeout]; null si no llega.
  Future<LatLng?> firstFix(Duration timeout) async {
    if (position.value != null) return position.value;
    final done = Completer<LatLng?>();
    void listener() {
      if (position.value != null && !done.isCompleted) {
        done.complete(position.value);
      }
    }

    position.addListener(listener);
    try {
      return await done.future.timeout(timeout, onTimeout: () => null);
    } finally {
      position.removeListener(listener);
    }
  }

  void _onPosition(Position p) {
    accuracy = p.accuracy;
    final moving = p.speed >= _minWalkingSpeed && p.heading >= 0;
    heading = moving ? p.heading : null;
    position.value = LatLng(p.latitude, p.longitude);
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    position.dispose();
  }
}
