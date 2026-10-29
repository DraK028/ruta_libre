import 'package:latlong2/latlong.dart';

import '../models/report.dart';
import 'geo.dart';

/// Reportes que conviene anunciar ahora: vigentes, cerca, de gravedad media
/// o alta y sin aviso reciente. El más cercano va primero.
List<Report> hazardsToAnnounce({
  required List<Report> reports,
  required LatLng me,
  required DateTime now,
  required Map<String, DateTime> lastAlerted,
  required double radiusMeters,
  required Duration cooldown,
}) {
  final due = reports.where((r) {
    if (!r.isActive(now) || r.severity == Severity.low) return false;
    if (distanceMeters(me, r.location) > radiusMeters) return false;
    final last = lastAlerted[r.id];
    return last == null || now.difference(last) >= cooldown;
  }).toList()
    ..sort((a, b) => distanceMeters(me, a.location)
        .compareTo(distanceMeters(me, b.location)));
  return due;
}
