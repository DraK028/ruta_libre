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

Color hazardColor(Severity s) =>
    s == Severity.low ? AppTheme.accessLimited : AppTheme.hazard;

const _markerShadow = [
  BoxShadow(color: Color(0x4D000000), blurRadius: 6, offset: Offset(0, 2)),
];

/// Círculo de estado con su ícono (en el mapa y en las listas).
class AccessBadge extends StatelessWidget {
  const AccessBadge({
    super.key,
    required this.access,
    this.size = 40,
    this.ring = false,
    this.square = false,
  });

  final Accessibility access;
  final double size;

  /// Aro blanco y sombra, para que resalte sobre el mapa.
  final bool ring;

  /// Los cruces son cuadrados; los lugares, círculos.
  final bool square;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accessColor(access),
        shape: square ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: square ? BorderRadius.circular(size * 0.22) : null,
        border: ring ? Border.all(color: Colors.white, width: 3) : null,
        boxShadow: ring ? _markerShadow : null,
      ),
      child: Icon(accessIcon(access), color: Colors.white, size: size * 0.5),
    );
  }
}

/// Lugar en el mapa (cuadrado si es un cruce).
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
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AccessBadge(
            access: place.access,
            size: crossing ? 26 : 40,
            ring: true,
            square: crossing,
          ),
        ),
      ),
    );
  }
}

/// Triángulo de peligro con aro blanco.
class HazardTriangle extends StatelessWidget {
  const HazardTriangle({super.key, required this.color, this.size = 44});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.92,
      child: CustomPaint(
        painter: _TrianglePainter(color),
        child: Align(
          alignment: const Alignment(0, 0.45),
          child: Icon(Icons.priority_high, color: Colors.white, size: size * 0.42),
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w / 2, 3)
      ..lineTo(w - 3, h - 3)
      ..lineTo(3, h - 3)
      ..close();
    canvas.drawShadow(path, Colors.black, 3, false);
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}

/// Peligro en el mapa; más grande si la gravedad es alta.
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
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: HazardTriangle(
            color: hazardColor(report.severity),
            size: report.severity == Severity.high ? 48 : 40,
          ),
        ),
      ),
    );
  }
}

/// Punto azul de "tú estás aquí", con halo.
class UserMarker extends StatelessWidget {
  const UserMarker({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Tu ubicación',
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.userDot.withValues(alpha: 0.22),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: AppTheme.userDot,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: _markerShadow,
          ),
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
    final text = Theme.of(context).textTheme;
    final rl = context.rl;
    Widget row(Widget badge, String title, String detail) => MergeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(width: 44, child: Center(child: badge)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.titleMedium),
                      Text(detail,
                          style: text.bodyMedium?.copyWith(color: rl.text2)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Qué significa cada marca', style: text.headlineSmall),
        const SizedBox(height: 8),
        for (final a in Accessibility.values)
          row(AccessBadge(access: a, size: 36), a.label, a.explanation),
        row(const HazardTriangle(color: AppTheme.hazard, size: 38),
            'Peligro reportado', 'Lo avisó la comunidad; caduca si nadie lo confirma'),
        const SizedBox(height: 4),
        Text('Los cuadrados son cruces; los círculos, lugares.',
            style: text.bodyMedium?.copyWith(color: rl.text2)),
      ],
    );
  }
}
