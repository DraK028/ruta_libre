import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/report.dart';

/// Dónde viven los reportes.
///
/// El prototipo usa [LocalReportRepository]. Para compartirlos entre
/// usuarios basta otra implementación (p. ej. API Gateway + Lambda +
/// DynamoDB) sin cambiar ninguna pantalla.
abstract interface class ReportRepository {
  Future<List<Report>> loadAll();
  Future<void> save(Report report);
}

/// Guarda los reportes en el teléfono como JSON.
class LocalReportRepository implements ReportRepository {
  LocalReportRepository(this._prefs);

  static const _key = 'reports';

  /// Reportes cerrados o caducados que se conservan antes de borrarse.
  static const _keepAfterExpiry = Duration(days: 30);

  final SharedPreferences _prefs;

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

  @override
  Future<void> save(Report report) async {
    final all = await loadAll();
    final index = all.indexWhere((r) => r.id == report.id);
    if (index == -1) {
      all.add(report);
    } else {
      all[index] = report;
    }
    await _prefs.setString(_key, jsonEncode(all.map((r) => r.toJson()).toList()));
  }
}
