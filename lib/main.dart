import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'app_state.dart';
import 'config.dart';
import 'services/location_service.dart';
import 'services/places_service.dart';
import 'services/report_repository.dart';
import 'services/routing_service.dart';
import 'services/voice_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  final state = AppState(
    prefs: prefs,
    voice: VoiceService(),
    location: LocationService(),
    places: PlacesService(prefs),
    reportsRepo: AppConfig.reportsApiUrl.isEmpty
        ? LocalReportRepository(prefs)
        : RemoteReportRepository(AppConfig.reportsApiUrl, prefs),
    routing: RoutingService(),
  );
  await state.init();

  runApp(RutaLibreApp(state: state));
}
