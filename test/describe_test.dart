import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ruta_libre/core/describe.dart';
import 'package:ruta_libre/core/voice_commands.dart';
import 'package:ruta_libre/models/place.dart';
import 'package:ruta_libre/models/report.dart';

void main() {
  const me = LatLng(19.3958, -99.0912);
  const north = LatLng(19.3962, -99.0912); // ~45 m al norte

  test('tiempo transcurrido y restante', () {
    final now = DateTime(2026, 10, 29, 12);
    expect(timeAgo(now.subtract(const Duration(seconds: 30)), now), 'hace un momento');
    expect(timeAgo(now.subtract(const Duration(minutes: 15)), now), 'hace 15 minutos');
    expect(timeAgo(now.subtract(const Duration(hours: 1)), now), 'hace una hora');
    expect(timeAgo(now.subtract(const Duration(days: 3)), now), 'hace 3 días');
    expect(timeUntil(now.add(const Duration(hours: 5)), now), 'en 5 horas');
    expect(timeUntil(now.subtract(const Duration(hours: 1)), now), 'ya caducó');
  });

  test('descripción hablada de un lugar', () {
    const p = Place(
      osmType: 'node',
      osmId: 1,
      name: 'Farmacia Ejemplo',
      category: 'Farmacia',
      location: north,
      kind: PlaceKind.poi,
      access: Accessibility.yes,
      accessibleToilet: true,
    );
    expect(
      describePlace(p, me: me),
      'Farmacia Ejemplo, farmacia. Accesible: entrada sin escalón. '
      'Tiene baño accesible. A 45 metros, al norte.',
    );
    // Caminando hacia el este, el norte queda a la izquierda.
    expect(describePlace(p, me: me, heading: 90), endsWith('A 45 metros, a tu izquierda.'));
    // Sin ubicación no se inventa distancia.
    expect(describePlace(p), isNot(contains('metros')));
  });

  test('descripción hablada de un reporte', () {
    final now = DateTime(2026, 10, 29, 12);
    final r = Report(
      id: '1',
      type: ReportType.openDrain,
      severity: Severity.high,
      location: north,
      createdAt: now.subtract(const Duration(hours: 2)),
      lastConfirmedAt: now.subtract(const Duration(hours: 2)),
      note: 'frente al banco',
    );
    expect(
      describeReport(r, now, me: me, heading: 0),
      'Coladera o registro abierto, gravedad alta. A 45 metros, al frente. '
      'Frente al banco. Confirmado hace 2 horas.',
    );
  });

  group('comandos de voz', () {
    test('reconoce cada comando sin importar acentos', () {
      expect(parseVoiceCommand('¿Qué hay cerca?'), VoiceCommand.nearby);
      expect(parseVoiceCommand('busca una farmacia'), VoiceCommand.nearby);
      expect(parseVoiceCommand('Reportar un obstáculo'), VoiceCommand.report);
      expect(parseVoiceCommand('¿Dónde estoy?'), VoiceCommand.whereAmI);
      expect(parseVoiceCommand('quitar ruta'), VoiceCommand.clearRoute);
      expect(parseVoiceCommand('configuración'), VoiceCommand.settings);
    });

    test('un peligro cerca es un reporte, no una consulta', () {
      expect(parseVoiceCommand('hay un peligro aquí cerca'), VoiceCommand.report);
    });

    test('frases sin comando', () {
      expect(parseVoiceCommand(''), VoiceCommand.unknown);
      expect(parseVoiceCommand('hola'), VoiceCommand.unknown);
    });
  });
}
