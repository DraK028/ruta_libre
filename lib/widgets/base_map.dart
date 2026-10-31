import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../core/theme.dart';
import '../models/route_result.dart';

/// Mosaicos de OpenStreetMap. En modo oscuro se invierten los colores para
/// que el mapa no deslumbre.
TileLayer osmTiles(BuildContext context) => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: AppConfig.packageName,
      maxZoom: 19,
      tileBuilder: Theme.of(context).brightness == Brightness.dark
          ? darkModeTileBuilder
          : null,
    );

/// Línea de la ruta con borde para que se lea sobre cualquier calle.
PolylineLayer routeLine(BuildContext context, RouteResult route) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return PolylineLayer(
    polylines: [
      Polyline(
        points: route.points,
        strokeWidth: 7,
        color: context.rl.primary,
        borderStrokeWidth: 3,
        borderColor: dark ? const Color(0xFF0B1B33) : Colors.white,
      ),
    ],
  );
}

/// Crédito de OpenStreetMap, siempre visible sobre el mapa.
class OsmCredit extends StatelessWidget {
  const OsmCredit({super.key});

  @override
  Widget build(BuildContext context) {
    final rl = context.rl;
    return Semantics(
      link: true,
      label: 'Datos del mapa: colaboradores de OpenStreetMap',
      excludeSemantics: true,
      child: Material(
        color: rl.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () =>
              launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text('© OpenStreetMap',
                style: TextStyle(fontSize: 12, color: rl.text2)),
          ),
        ),
      ),
    );
  }
}
