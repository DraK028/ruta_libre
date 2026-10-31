import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/geo.dart';
import '../models/report.dart';

/// Error al sincronizar un reporte, con un mensaje listo para mostrar y decir.
class ReportSyncException implements Exception {
  const ReportSyncException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// No se pudo llegar al servidor (sin red o tiempo agotado).
class ReportOfflineException extends ReportSyncException {
  const ReportOfflineException()
      : super('No hay conexión con el servidor de reportes.');
}

/// Dónde viven los reportes.
///
/// [LocalReportRepository] los guarda solo en el teléfono.
/// [RemoteReportRepository] los comparte con todas las personas por medio de
/// la API de `server/` y conserva una copia local para usarlos sin conexión.
abstract interface class ReportRepository {
  /// Si los reportes se comparten con otras personas.
  bool get shared;

  /// Reportes conocidos en este teléfono (al instante, sin red).
  Future<List<Report>> loadAll();

  /// Trae los reportes cercanos a [center] y devuelve todos los conocidos.
  Future<List<Report>> refresh(LatLng center);

  /// Guarda un reporte nuevo. Puede devolverlo con otro `id` (el del servidor).
  Future<Report> create(Report draft);

  /// "Sigue ahí".
  Future<Report> confirm(Report report);

  /// "Ya no está".
  Future<Report> voteGone(Report report);
}

/// Guarda los reportes en el teléfono como JSON.
class LocalReportRepository implements ReportRepository {
  LocalReportRepository(this._prefs);

  static const _key = 'reports';

  /// Reportes cerrados o caducados que se conservan antes de borrarse.
  static const _keepAfterExpiry = Duration(days: 30);

  final SharedPreferences _prefs;

  @override
  bool get shared => false;

  @override
  Future<List<Report>> loadAll() async {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    final now = DateTime.now();
    return list
        .map((e) => Report.fromJson((e as Map).cast<String, Object?>()))
        .where((r) => now.difference(r.expiresAt) < _keepAfterExpiry)
        .toList();
  }

  /// Reemplaza el reporte con el mismo `id` o lo agrega.
  Future<void> save(Report report) => saveAll([report]);

  Future<void> saveAll(Iterable<Report> reports) async {
    final all = await loadAll();
    for (final report in reports) {
      final index = all.indexWhere((r) => r.id == report.id);
      if (index == -1) {
        all.add(report);
      } else {
        all[index] = report;
      }
    }
    await _write(all);
  }

  Future<void> remove(Iterable<String> ids) async {
    final drop = ids.toSet();
    if (drop.isEmpty) return;
    final all = await loadAll();
    await _write(all.where((r) => !drop.contains(r.id)));
  }

  Future<void> _write(Iterable<Report> all) =>
      _prefs.setString(_key, jsonEncode(all.map((r) => r.toJson()).toList()));

  @override
  Future<List<Report>> refresh(LatLng center) => loadAll();

  @override
  Future<Report> create(Report draft) async {
    await save(draft);
    return draft;
  }

  @override
  Future<Report> confirm(Report report) async {
    final updated = report.confirm(DateTime.now());
    await save(updated);
    return updated;
  }

  @override
  Future<Report> voteGone(Report report) async {
    final updated = report.voteGone();
    await save(updated);
    return updated;
  }
}

/// Comparte los reportes por medio de la API de `server/` (AWS).
///
/// - Cada teléfono se identifica con un código anónimo aleatorio.
/// - Si no hay conexión al reportar, el reporte se guarda como pendiente y se
///   envía en la siguiente sincronización.
/// - Las fotos no se suben: se quedan en el teléfono de quien reporta.
class RemoteReportRepository implements ReportRepository {
  RemoteReportRepository(
    String baseUrl,
    this._prefs, {
    http.Client? client,
    this.radiusMeters = 2000,
  })  : _base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _client = client ?? http.Client(),
        _local = LocalReportRepository(_prefs);

  static const _kDevice = 'device_id';
  static const pendingPrefix = 'pendiente-';
  static const _timeout = Duration(seconds: 15);

  final String _base;
  final SharedPreferences _prefs;
  final http.Client _client;
  final LocalReportRepository _local;
  final double radiusMeters;

  @override
  bool get shared => true;

  /// Código anónimo de este teléfono (no se relaciona con la persona).
  String get deviceId {
    final saved = _prefs.getString(_kDevice);
    if (saved != null) return saved;
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random.secure();
    final id = List.generate(24, (_) => chars[rnd.nextInt(chars.length)]).join();
    _prefs.setString(_kDevice, id);
    return id;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=utf-8',
        'X-Device-Id': deviceId,
      };

  static bool _isPending(Report r) => r.id.startsWith(pendingPrefix);

  @override
  Future<List<Report>> loadAll() => _local.loadAll();

  /// Conserva los datos que solo existen en este teléfono (la foto).
  Report _withLocal(Report fromServer, Report? local) {
    final photo = local?.photoPath;
    if (photo == null) return fromServer;
    final json = fromServer.toJson()..['photoPath'] = photo;
    return Report.fromJson(json);
  }

  Future<Map<String, Object?>> _send(
      String method, String path, [Map<String, Object?>? body]) async {
    final uri = Uri.parse('$_base$path');
    final http.Response res;
    try {
      res = await (method == 'GET'
              ? _client.get(uri, headers: _headers)
              : _client.post(uri, headers: _headers, body: jsonEncode(body ?? {})))
          .timeout(_timeout);
    } on Exception {
      throw const ReportOfflineException();
    }
    Map<String, Object?> json;
    try {
      json = (jsonDecode(utf8.decode(res.bodyBytes)) as Map).cast<String, Object?>();
    } on Object {
      json = const {};
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return json;
    final message = json['error'] as String?;
    throw ReportSyncException(message ?? 'El servidor respondió con error ${res.statusCode}.');
  }

  Report _parse(Map<String, Object?> json) =>
      Report.fromJson((json['report'] as Map).cast<String, Object?>());

  Map<String, Object?> _createBody(Report r) => {
        'type': r.type.name,
        'severity': r.severity.name,
        'lat': r.location.latitude,
        'lon': r.location.longitude,
        'note': r.note,
      };

  @override
  Future<Report> create(Report draft) async {
    try {
      final saved = _withLocal(_parse(await _send('POST', '/reports', _createBody(draft))), draft);
      await _local.save(saved);
      return saved;
    } on ReportOfflineException {
      // Sin red: se guarda como pendiente y se envía después.
      final json = draft.toJson()..['id'] = '$pendingPrefix${draft.id}';
      final pending = Report.fromJson(json);
      await _local.save(pending);
      return pending;
    }
  }

  /// Envía los reportes que se crearon sin conexión.
  Future<void> _flushPending() async {
    final pending = (await _local.loadAll()).where(_isPending).toList();
    for (final p in pending) {
      try {
        final saved = _withLocal(_parse(await _send('POST', '/reports', _createBody(p))), p);
        await _local.remove([p.id]);
        await _local.save(saved);
      } on ReportOfflineException {
        return; // se intenta en la siguiente sincronización
      } on ReportSyncException {
        await _local.remove([p.id]); // rechazado por el servidor: se descarta
      }
    }
  }

  @override
  Future<List<Report>> refresh(LatLng center) async {
    try {
      await _flushPending();
      final json = await _send('GET',
          '/reports?lat=${center.latitude}&lon=${center.longitude}&radius=${radiusMeters.round()}');
      final remote = ((json['reports'] as List?) ?? const [])
          .map((e) => Report.fromJson((e as Map).cast<String, Object?>()))
          .toList();
      final local = await _local.loadAll();
      final byId = {for (final r in local) r.id: r};
      final remoteIds = remote.map((r) => r.id).toSet();
      // Reportes del servidor en esta zona que ya no vienen: se cerraron o
      // caducaron en otro teléfono.
      final gone = local.where((r) =>
          !_isPending(r) &&
          !remoteIds.contains(r.id) &&
          distanceMeters(center, r.location) <= radiusMeters);
      await _local.remove(gone.map((r) => r.id));
      await _local.saveAll(remote.map((r) => _withLocal(r, byId[r.id])));
    } on ReportSyncException {
      // Sin red: se usa lo guardado.
    }
    return _local.loadAll();
  }

  Future<Report> _vote(Report report, String action, Report Function() offline) async {
    if (_isPending(report)) {
      final updated = offline();
      await _local.save(updated);
      return updated;
    }
    final saved =
        _withLocal(_parse(await _send('POST', '/reports/${report.id}/$action')), report);
    await _local.save(saved);
    return saved;
  }

  @override
  Future<Report> confirm(Report report) =>
      _vote(report, 'confirm', () => report.confirm(DateTime.now()));

  @override
  Future<Report> voteGone(Report report) =>
      _vote(report, 'gone', report.voteGone);
}
