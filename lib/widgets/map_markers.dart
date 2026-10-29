import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/place.dart';
import '../models/report.dart';

Color accessColor(Accessibility a) => switch (a) {
      Accessibility.yes => AppTheme.accessYes,
      Accessibility.limited => AppTheme.accessLimited,
      Accessibility.no => AppTheme.accessNo,
      Accessibility.unknown => AppTheme.accessUnknown,
    };

/// Ícono distinto por estado: así se distingue sin depender del color.
IconData accessIcon(Accessibility a) => switch (a) {
      Accessibility.yes => Icons.check,
      Accessibility.limited => Icons.remove,
      Accessibility.no => Icons.close,
      Accessibility.unknown => Icons.question_mark,
    };

/// Círculo de un lugar en el mapa (cuadrado si es un cruce).
class PlaceMarker extends StatelessWidget {
  const PlaceMarker({
    super.key,
    required this.place,
    required this.semanticLabel,
    required this.onTap,
  });

  final Place place;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final crossing = place.kind == PlaceKind.crossing;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: accessColor(place.access),
            shape: crossing ? BoxShape.rectangle : BoxShape.circle,
            borderRadius: crossing ? BorderRadius.circular(6) : null,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
          ),
          child: Icon(
            accessIcon(place.access),
            color: Colors.white,
            size: crossing ? 18 : 26,
          ),
        ),
      ),
    );
  }
}

/// Triángulo de peligro; más grande si la gravedad es alta.
class HazardMarker extends StatelessWidget {
  const HazardMarker({
    super.key,
    required this.report,
    required this.semanticLabel,
    required this.onTap,
  });

  final Report report;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.warning, color: Colors.black, size: 52),
            Icon(
              Icons.warning,
              color: report.severity == Severity.high
                  ? AppTheme.hazard
                  : AppTheme.accessLimited,
              size: 44,
            ),
          ],
        ),
      ),
    );
  }
}

/// Punto azul de "tú estás aquí".
class UserMarker extends StatelessWidget {
  const UserMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Tu ubicación',
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2F80ED),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
        ),
      ),
    );
  }
}

/// Leyenda de colores e íconos, para quien ve el mapa por primera vez.
class AccessLegend extends StatelessWidget {
  const AccessLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget row(Accessibility a) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: accessColor(a),
                child: Icon(accessIcon(a), color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('${a.label}: ${a.explanation}',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final a in Accessibility.values) row(a),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              const Icon(Icons.warning, color: AppTheme.hazard, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Peligro reportado por la comunidad',
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
            ],
          ),
        ),
        Text('Los cuadrados son cruces; los círculos, lugares.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.textMuted)),
      ],
    );
  }
}
