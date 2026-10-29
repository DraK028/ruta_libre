import 'package:latlong2/latlong.dart';

enum Severity {
  low('Baja'),
  medium('Media'),
  high('Alta');

  const Severity(this.label);
  final String label;
}

/// Tipos de peligro con su gravedad por defecto y cuánto duran sin confirmar.
///
/// Lo temporal caduca rápido (un coche se mueve); lo estructural dura más.
enum ReportType {
  blockedRamp('Rampa bloqueada', Severity.high, Duration(hours: 6)),
  openDrain('Coladera o registro abierto', Severity.high, Duration(days: 3)),
  brokenSidewalk('Banqueta rota o levantada', Severity.medium, Duration(days: 30)),
  construction('Obra o desvío', Severity.medium, Duration(days: 14)),
  noRamp('Sin rampa en el cruce', Severity.medium, Duration(days: 90)),
  elevatorOut('Elevador fuera de servicio', Severity.high, Duration(days: 2)),
  flooding('Inundación o encharcamiento', Severity.high, Duration(days: 1)),
  other('Otro peligro', Severity.medium, Duration(days: 7));

  const ReportType(this.label, this.defaultSeverity, this.ttl);
  final String label;
  final Severity defaultSeverity;
  final Duration ttl;
}

/// Un peligro u obstáculo reportado por la comunidad.
///
/// Es inmutable: confirmar o votar devuelve un reporte nuevo.
class Report {
  const Report({
    required this.id,
    required this.type,
    required this.severity,
    required this.location,
    required this.createdAt,
    required this.lastConfirmedAt,
    this.goneVotes = 0,
    this.closed = false,
    this.note = '',
    this.photoPath,
  });

  /// Votos "ya no está" seguidos que cierran un reporte.
  static const votesToClose = 2;

  final String id;
  final ReportType type;
  final Severity severity;
  final LatLng location;
  final DateTime createdAt;

  /// Última vez que alguien dijo "sigue ahí" (o la creación).
  final DateTime lastConfirmedAt;

  /// "Ya no está" seguidos desde la última confirmación.
  final int goneVotes;
  final bool closed;
  final String note;
  final String? photoPath;

  DateTime get expiresAt => lastConfirmedAt.add(type.ttl);

  bool isActive(DateTime now) => !closed && now.isBefore(expiresAt);

  /// "Sigue ahí": reinicia la caducidad y borra los votos en contra.
  Report confirm(DateTime now) =>
      _copy(lastConfirmedAt: now, goneVotes: 0, closed: false);

  /// "Ya no está": con [votesToClose] votos seguidos se cierra.
  Report voteGone() {
    final votes = goneVotes + 1;
    return _copy(goneVotes: votes, closed: votes >= votesToClose);
  }

  Report _copy({DateTime? lastConfirmedAt, int? goneVotes, bool? closed}) =>
      Report(
        id: id,
        type: type,
        severity: severity,
        location: location,
        createdAt: createdAt,
        lastConfirmedAt: lastConfirmedAt ?? this.lastConfirmedAt,
        goneVotes: goneVotes ?? this.goneVotes,
        closed: closed ?? this.closed,
        note: note,
        photoPath: photoPath,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type.name,
        'severity': severity.name,
        'lat': location.latitude,
        'lon': location.longitude,
        'createdAt': createdAt.toIso8601String(),
        'lastConfirmedAt': lastConfirmedAt.toIso8601String(),
        'goneVotes': goneVotes,
        'closed': closed,
        'note': note,
        'photoPath': photoPath,
      };

  factory Report.fromJson(Map<String, Object?> json) => Report(
        id: json['id'] as String,
        type: ReportType.values.byName(json['type'] as String),
        severity: Severity.values.byName(json['severity'] as String),
        location: LatLng(
          (json['lat'] as num).toDouble(),
          (json['lon'] as num).toDouble(),
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastConfirmedAt: DateTime.parse(json['lastConfirmedAt'] as String),
        goneVotes: (json['goneVotes'] as int?) ?? 0,
        closed: (json['closed'] as bool?) ?? false,
        note: (json['note'] as String?) ?? '',
        photoPath: json['photoPath'] as String?,
      );
}
