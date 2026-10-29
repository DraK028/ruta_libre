import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:ruta_libre/core/hazard_alerts.dart';
import 'package:ruta_libre/models/report.dart';

Report _report({
  String id = 'r1',
  ReportType type = ReportType.blockedRamp,
  Severity? severity,
  LatLng location = const LatLng(19.3958, -99.0912),
  required DateTime at,
}) =>
    Report(
      id: id,
      type: type,
      severity: severity ?? type.defaultSeverity,
      location: location,
      createdAt: at,
      lastConfirmedAt: at,
    );

void main() {
  final t0 = DateTime(2026, 10, 29, 8);

  group('ciclo de vida', () {
    test('caduca según su tipo', () {
      final r = _report(at: t0); // rampa bloqueada: 6 horas
      expect(r.isActive(t0.add(const Duration(hours: 5))), isTrue);
      expect(r.isActive(t0.add(const Duration(hours: 6))), isFalse);
    });

    test('"sigue ahí" reinicia la caducidad y borra votos en contra', () {
      final r = _report(at: t0).voteGone();
      expect(r.goneVotes, 1);
      final confirmed = r.confirm(t0.add(const Duration(hours: 5)));
      expect(confirmed.goneVotes, 0);
      expect(confirmed.isActive(t0.add(const Duration(hours: 10))), isTrue);
    });

    test('dos "ya no está" seguidos lo cierran', () {
      final once = _report(at: t0).voteGone();
      expect(once.closed, isFalse);
      final twice = once.voteGone();
      expect(twice.closed, isTrue);
      expect(twice.isActive(t0), isFalse);
    });

    test('ida y vuelta por JSON', () {
      final r = _report(at: t0, type: ReportType.openDrain).voteGone();
      final back = Report.fromJson(r.toJson());
      expect(back.type, ReportType.openDrain);
      expect(back.severity, Severity.high);
      expect(back.goneVotes, 1);
      expect(back.expiresAt, r.expiresAt);
    });
  });

  group('avisos de peligro', () {
    const me = LatLng(19.3958, -99.0912);
    const near = LatLng(19.39595, -99.0912); // ~17 m
    const far = LatLng(19.3968, -99.0912); // ~111 m

    List<Report> due(List<Report> reports, Map<String, DateTime> last,
            {DateTime? now}) =>
        hazardsToAnnounce(
          reports: reports,
          me: me,
          now: now ?? t0,
          lastAlerted: last,
          radiusMeters: 30,
          cooldown: const Duration(minutes: 10),
        );

    test('avisa solo lo cercano, vigente y no leve', () {
      final reports = [
        _report(id: 'cerca', location: near, at: t0),
        _report(id: 'lejos', location: far, at: t0),
        _report(id: 'leve', location: near, severity: Severity.low, at: t0),
        _report(id: 'vencido', location: near,
            at: t0.subtract(const Duration(days: 1))),
      ];
      expect(due(reports, {}).map((r) => r.id), ['cerca']);
    });

    test('no repite el aviso antes del tiempo de espera', () {
      final reports = [_report(id: 'a', location: near, at: t0)];
      final last = {'a': t0.subtract(const Duration(minutes: 5))};
      expect(due(reports, last), isEmpty);
      expect(due(reports, last, now: t0.add(const Duration(minutes: 6))),
          hasLength(1));
    });

    test('el más cercano va primero', () {
      final reports = [
        _report(id: 'b', location: const LatLng(19.39600, -99.0912), at: t0),
        _report(id: 'a', location: near, at: t0),
      ];
      expect(due(reports, {}).map((r) => r.id), ['a', 'b']);
    });
  });
}
