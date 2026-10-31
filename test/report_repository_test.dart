import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:ruta_libre/models/report.dart';
import 'package:ruta_libre/services/report_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _here = LatLng(19.3958, -99.0912);
const _serverId = '0123456789abcdef0123456789abcdef';

Report _draft({String? photo}) {
  final now = DateTime(2026, 10, 31, 9);
  return Report(
    id: '1',
    type: ReportType.blockedRamp,
    severity: Severity.high,
    location: _here,
    createdAt: now,
    lastConfirmedAt: now,
    note: 'Coche gris',
    photoPath: photo,
  );
}

Map<String, Object?> _serverReport({int gone = 0, bool closed = false}) => {
      'id': _serverId,
      'type': 'blockedRamp',
      'severity': 'high',
      'lat': _here.latitude,
      'lon': _here.longitude,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'lastConfirmedAt': DateTime.now().toUtc().toIso8601String(),
      'goneVotes': gone,
      'closed': closed,
      'note': 'Coche gris',
      'photoPath': null,
    };

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('crear manda el reporte, guarda el id del servidor y conserva la foto',
      () async {
    late http.Request sent;
    final repo = RemoteReportRepository('https://api.test/piloto/', prefs,
        client: MockClient((req) async {
      sent = req;
      return http.Response(jsonEncode({'report': _serverReport()}), 201);
    }));
    final saved = await repo.create(_draft(photo: '/fotos/a.jpg'));

    expect(sent.url.toString(), 'https://api.test/piloto/reports');
    expect(sent.headers['X-Device-Id'], hasLength(24));
    final body = jsonDecode(sent.body) as Map;
    expect(body['type'], 'blockedRamp');
    expect(body.containsKey('photoPath'), isFalse); // la foto no se sube
    expect(saved.id, _serverId);
    expect(saved.photoPath, '/fotos/a.jpg');
    expect((await repo.loadAll()).single.id, _serverId);
  });

  test('sin conexión queda pendiente y se envía al sincronizar', () async {
    var online = false;
    final repo = RemoteReportRepository('https://api.test', prefs,
        client: MockClient((req) async {
      if (!online) throw http.ClientException('sin red');
      if (req.method == 'POST') {
        return http.Response(jsonEncode({'report': _serverReport()}), 201);
      }
      return http.Response(jsonEncode({'reports': [_serverReport()]}), 200);
    }));
    final pending = await repo.create(_draft());
    expect(pending.id, startsWith(RemoteReportRepository.pendingPrefix));

    online = true;
    final all = await repo.refresh(_here);
    expect(all.map((r) => r.id), [_serverId]);
  });

  test('refrescar quita los reportes cerrados en otros teléfonos', () async {
    var reports = [_serverReport()];
    final repo = RemoteReportRepository('https://api.test', prefs,
        client: MockClient((req) async =>
            http.Response(jsonEncode({'reports': reports}), 200)));
    expect(await repo.refresh(_here), hasLength(1));
    reports = [];
    expect(await repo.refresh(_here), isEmpty);
  });

  test('error del servidor se informa con su mensaje', () async {
    final repo = RemoteReportRepository('https://api.test', prefs,
        client: MockClient((req) async => http.Response(
            jsonEncode({'error': 'Hiciste muchos reportes en poco tiempo.'}),
            429)));
    expect(
      () => repo.create(_draft()),
      throwsA(isA<ReportSyncException>().having(
          (e) => e.message, 'message', contains('muchos reportes'))),
    );
  });

  test('el código del teléfono es estable', () async {
    final repo = RemoteReportRepository('https://api.test', prefs,
        client: MockClient((_) async => http.Response('{}', 200)));
    expect(repo.deviceId, repo.deviceId);
  });

  test('sin servidor todo queda en el teléfono', () async {
    final repo = LocalReportRepository(prefs);
    final r = await repo.create(_draft());
    final gone = await repo.voteGone(r);
    expect(gone.goneVotes, 1);
    expect((await repo.refresh(_here)).single.goneVotes, 1);
  });
}
