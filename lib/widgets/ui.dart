import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../core/describe.dart';
import '../core/geo.dart';
import '../core/theme.dart';
import '../models/place.dart';
import '../models/report.dart';
import 'map_markers.dart';

/// Piezas visuales que comparten varias pantallas.

const cardShadow = [
  BoxShadow(color: Color(0x1F000000), blurRadius: 10, offset: Offset(0, 2)),
];

/// Barrita para arrastrar una hoja inferior.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: Center(
          child: Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: context.rl.handle,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      );
}

/// Botón cuadrado flotante sobre el mapa (leyenda, centrar, volver).
class MapIconButton extends StatelessWidget {
  const MapIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final rl = context.rl;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: cardShadow,
          ),
          child: Material(
            color: rl.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: rl.border),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onPressed,
              child: SizedBox(
                width: 48,
                height: 48,
                child: Icon(icon, size: 24, color: color ?? rl.text),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Píldora de filtro: azul con palomita si está activa.
class FilterPill extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final rl = context.rl;
    final fg = selected ? rl.onPrimary : rl.text;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Filtro: $label',
      excludeSemantics: true,
      child: Material(
        color: selected ? rl.primary : rl.surface,
        shape: StadiumBorder(
          side: selected ? BorderSide.none : BorderSide(color: rl.border),
        ),
        elevation: selected ? 0 : 1,
        shadowColor: Colors.black26,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    Icon(Icons.check, size: 18, color: fg),
                    const SizedBox(width: 6),
                  ] else if (icon != null) ...[
                    Icon(icon, size: 18, color: rl.text2),
                    const SizedBox(width: 6),
                  ],
                  Text(label,
                      style: TextStyle(
                        fontSize: 15,
                        color: fg,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Control segmentado (Lugares | Peligros, Baja | Media | Alta…).
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.semanticPrefix = '',
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final String semanticPrefix;

  @override
  Widget build(BuildContext context) {
    final rl = context.rl;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: rl.surface2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final v in values)
            Expanded(
              child: Semantics(
                button: true,
                selected: v == selected,
                label: '$semanticPrefix${labelOf(v)}',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => onChanged(v),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    constraints: const BoxConstraints(minHeight: 44),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    decoration: BoxDecoration(
                      color: v == selected ? rl.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: v == selected
                          ? const [
                              BoxShadow(
                                  color: Color(0x26000000),
                                  blurRadius: 3,
                                  offset: Offset(0, 1)),
                            ]
                          : null,
                    ),
                    child: Text(
                      labelOf(v),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: v == selected ? rl.text : rl.text2,
                        fontWeight:
                            v == selected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Etiqueta de color suave ("Sin escaleras", "Evita 1 peligro").
class Tag extends StatelessWidget {
  const Tag({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: foreground)),
            ),
          ],
        ),
      );
}

/// Fondo suave y color de texto para el estado de accesibilidad.
({Color background, Color foreground}) accessTone(
    BuildContext context, Accessibility a) {
  final rl = context.rl;
  final dark = Theme.of(context).brightness == Brightness.dark;
  if (a == Accessibility.yes) return (background: rl.okSoft, foreground: rl.okText);
  final base = accessColor(a);
  return (
    background: base.withValues(alpha: dark ? 0.22 : 0.12),
    foreground: dark ? Color.lerp(base, Colors.white, 0.55)! : base,
  );
}

/// "Entrada sin escalón · Baño accesible".
String placeSummary(Place p) {
  final parts = <String>[
    switch (p.access) {
      Accessibility.yes => 'Entrada sin escalón',
      Accessibility.limited => 'Acceso limitado',
      Accessibility.no => 'No accesible',
      Accessibility.unknown => 'Sin dato de accesibilidad',
    },
    if (p.accessibleToilet == true) 'Baño accesible',
  ];
  return parts.join(' · ');
}

/// Distancia corta y dirección, en dos renglones a la derecha de una fila.
class _DistanceColumn extends StatelessWidget {
  const _DistanceColumn({required this.target, required this.me, this.heading});
  final LatLng target;
  final LatLng? me;
  final double? heading;

  @override
  Widget build(BuildContext context) {
    final me = this.me;
    if (me == null) return const SizedBox.shrink();
    final rl = context.rl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(formatDistanceShort(distanceMeters(me, target)),
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: rl.text)),
        Text(directionFrom(me, target, heading),
            style: TextStyle(fontSize: 13, color: rl.text2)),
      ],
    );
  }
}

/// Fila de un lugar en "Cerca de ti".
class PlaceRow extends StatelessWidget {
  const PlaceRow({
    super.key,
    required this.place,
    required this.me,
    required this.heading,
    required this.onTap,
  });

  final Place place;
  final LatLng? me;
  final double? heading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rl = context.rl;
    final title = place.name == place.category
        ? place.name
        : '${place.name} · ${place.category}';
    return Semantics(
      button: true,
      label: describePlace(place, me: me, heading: heading),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: rl.border)),
          ),
          child: Row(
            children: [
              AccessBadge(access: place.access),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: rl.text)),
                    const SizedBox(height: 2),
                    Text(placeSummary(place),
                        style: TextStyle(fontSize: 14, color: rl.text2)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _DistanceColumn(target: place.location, me: me, heading: heading),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila de un peligro en "Cerca de ti".
class HazardRow extends StatelessWidget {
  const HazardRow({
    super.key,
    required this.report,
    required this.me,
    required this.heading,
    required this.onTap,
  });

  final Report report;
  final LatLng? me;
  final double? heading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rl = context.rl;
    final now = DateTime.now();
    return Semantics(
      button: true,
      label: describeReport(report, now, me: me, heading: heading),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: rl.border)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: HazardTriangle(
                    color: hazardColor(report.severity), size: 36),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(report.type.label,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: rl.text)),
                    const SizedBox(height: 2),
                    Text(
                        'Gravedad ${report.severity.label.toLowerCase()} · '
                        'confirmado ${timeAgo(report.lastConfirmedAt, now)}',
                        style: TextStyle(fontSize: 14, color: rl.text2)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _DistanceColumn(target: report.location, me: me, heading: heading),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mensaje centrado cuando una lista está vacía.
class EmptyNote extends StatelessWidget {
  const EmptyNote(this.message, {super.key, this.icon = Icons.search_off});
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final rl = context.rl;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(icon, size: 36, color: rl.text2),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: rl.text2)),
        ],
      ),
    );
  }
}

/// Botón redondo de "escuchar" (bocina) con fondo azul suave.
class ListenButton extends StatelessWidget {
  const ListenButton({super.key, required this.onPressed, this.label});

  final VoidCallback onPressed;

  /// Si es null solo se muestra el ícono.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final rl = context.rl;
    if (label == null) {
      return IconButton.filled(
        tooltip: 'Escuchar',
        iconSize: 24,
        style: IconButton.styleFrom(
          backgroundColor: rl.primarySoft,
          foregroundColor: rl.primary,
          minimumSize: const Size(48, 48),
        ),
        onPressed: onPressed,
        icon: const Icon(Icons.volume_up_outlined),
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.volume_up_outlined, size: 20),
      label: Text(label!),
    );
  }
}
