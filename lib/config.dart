import 'package:latlong2/latlong.dart';

/// Configuración del piloto. Ajusta estos valores a tu caso.
class AppConfig {
  /// Centro aproximado de UPIICSA (Av. Té 950, Granjas México, Iztacalco).
  /// Verifícalo en openstreetmap.org y ajústalo si hace falta.
  static const pilotCenter = LatLng(19.3958, -99.0912);

  /// Radio de la zona piloto en metros.
  static const pilotRadiusMeters = 1000;

  /// Identificador de la app para OpenStreetMap (User-Agent).
  /// La política de OSM pide uno propio y con forma de contacto.
  static const packageName = 'com.drak028.ruta_libre';
  static const userAgent =
      'RutaLibre/0.1 (prototipo estudiantil; https://github.com/DraK028)';

  static const overpassUrl = 'https://overpass-api.de/api/interpreter';
  static const orsBaseUrl = 'https://api.openrouteservice.org/v2/directions';

  /// Clave de openrouteservice. No se guarda en el código:
  /// `flutter run --dart-define=ORS_API_KEY=tu_clave`
  static const orsApiKey = String.fromEnvironment('ORS_API_KEY');

  /// Cada cuánto se vuelven a descargar los lugares de una zona.
  static const placesCacheTtl = Duration(days: 7);

  /// "Cerca de ti" solo lista lo que está a esta distancia o menos, para que
  /// alguien lejos de la zona piloto no vea UPIICSA como "cercano".
  static const nearbyMaxMeters = 3000.0;

  /// Tiempo máximo que se espera la primera ubicación al abrir la app antes
  /// de descargar la zona piloto.
  static const firstFixTimeout = Duration(seconds: 12);

  /// Espera mínima entre descargas automáticas al moverse (por si falla la red).
  static const autoLoadCooldown = Duration(minutes: 1);

  /// Distancia a la que se avisa de un peligro reportado.
  static const hazardAlertMeters = 30.0;

  /// Tiempo mínimo antes de repetir el aviso del mismo peligro.
  static const hazardAlertCooldown = Duration(minutes: 10);
}
