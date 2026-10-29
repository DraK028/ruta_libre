import 'package:latlong2/latlong.dart';

import '../models/place.dart';
import '../models/report.dart';
import 'geo.dart';

/// "hace 5 minutos", "hace 2 horas", "hace 3 días".
String timeAgo(DateTime then, DateTime now) {
  final d = now.difference(then);
  if (d.inMinutes < 2) return 'hace un momento';
  if (d.inMinutes < 60) return 'hace ${d.inMinutes} minutos';
  if (d.inHours < 24) {
    return d.inHours == 1 ? 'hace una hora' : 'hace ${d.inHours} horas';
  }
  return d.inDays == 1 ? 'hace un día' : 'hace ${d.inDays} días';
}

/// "en 3 horas", "en 2 días".
String timeUntil(DateTime when, DateTime now) {
  final d = when.difference(now);
  if (d.isNegative) return 'ya caducó';
  if (d.inMinutes < 60) return 'en ${d.inMinutes} minutos';
  if (d.inHours < 24) {
    return d.inHours == 1 ? 'en una hora' : 'en ${d.inHours} horas';
  }
  return d.inDays == 1 ? 'en un día' : 'en ${d.inDays} días';
}

/// "a 40 metros, a tu derecha". Vacío si no se conoce la ubicación.
String whereIs(LatLng target, LatLng? me, double? heading) {
  if (me == null) return '';
  final meters = distanceMeters(me, target);
  return 'a ${formatDistance(meters)}, ${directionFrom(me, target, heading)}';
}

/// Lo que se lee en voz alta de un lugar.
String describePlace(Place p, {LatLng? me, double? heading}) {
  final parts = <String>[
    p.name == p.category ? p.name : '${p.name}, ${p.category.toLowerCase()}',
    '${p.access.label}: ${p.access.explanation}',
  ];
  if (p.accessibleToilet == true) parts.add('Tiene baño accesible');
  if (p.accessibleToilet == false) parts.add('Su baño no es accesible');
  if (p.tactilePaving == true) parts.add('Tiene guía podotáctil');
  final desc = p.description?.trim();
  if (desc != null && desc.isNotEmpty) parts.add(desc);
  final where = whereIs(p.location, me, heading);
  if (where.isNotEmpty) parts.add(_capitalize(where));
  return '${parts.join('. ')}.';
}

/// Lo que se lee en voz alta de un reporte.
String describeReport(Report r, DateTime now, {LatLng? me, double? heading}) {
  final parts = <String>[
    '${r.type.label}, gravedad ${r.severity.label.toLowerCase()}',
  ];
  final where = whereIs(r.location, me, heading);
  if (where.isNotEmpty) parts.add(_capitalize(where));
  final note = r.note.trim();
  if (note.isNotEmpty) parts.add(_capitalize(note));
  parts.add('Confirmado ${timeAgo(r.lastConfirmedAt, now)}');
  return '${parts.join('. ')}.';
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
