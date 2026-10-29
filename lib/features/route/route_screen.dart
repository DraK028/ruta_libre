import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/geo.dart';
import '../../core/route_api.dart';
import '../../core/theme.dart';
import '../../models/place.dart';
import '../../models/route_result.dart';
import '../../services/routing_service.dart';

/// Calcula la ruta a [destination] (o muestra la ruta activa) con sus
/// indicaciones, una por renglón, para leerlas o escucharlas.
class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key, this.destination});

  /// Null = mostrar la ruta que ya está activa en el mapa.
  final Place? destination;

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  RouteResult? _route;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = AppScope.read(context);
      if (widget.destination == null) {
        setState(() => _route = app.route);
        if (_route != null) app.voice.announce(spokenSummary(_route!));
      } else {
        _calculate();
      }
    });
  }

  Future<void> _calculate() async {
    final app = AppScope.read(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    await app.voice.announce('Calculando una ruta accesible.');
    try {
      final route = await app.routeTo(widget.destination!);
      if (!mounted) return;
      setState(() => _route = route);
      await app.voice.speak(
          '${spokenSummary(route)} Toca Escuchar indicaciones o Ver en el mapa.');
    } on RoutingException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
      await app.voice.speak(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _speakAll(AppState app, RouteResult route) async {
    final text = [
      spokenSummary(route),
      for (final s in route.steps) spokenStep(s),
    ].join(' ');
    await app.voice.speak(text);
  }

  IconData _stepIcon(int type) => switch (type) {
        0 || 2 || 4 || 12 => Icons.turn_left,
        1 || 3 || 5 || 13 => Icons.turn_right,
        7 || 8 => Icons.roundabout_left,
        9 => Icons.u_turn_left,
        10 => Icons.flag,
        11 => Icons.directions_walk,
        _ => Icons.straight,
      };

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = Theme.of(context).textTheme;
    final route = _route;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.destination == null
            ? 'Indicaciones'
            : 'Ir a ${widget.destination!.name}'),
      ),
      body: SafeArea(
        child: Builder(builder: (context) {
          if (_loading) {
            return Center(
              child: Semantics(
                liveRegion: true,
                label: 'Calculando ruta',
                child: const CircularProgressIndicator(),
              ),
            );
          }
          if (_error != null) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.wrong_location, size: 80, color: AppTheme.danger),
                  const SizedBox(height: 16),
                  Text(_error!, textAlign: TextAlign.center, style: text.titleLarge),
                  const SizedBox(height: 24),
                  if (widget.destination != null)
                    ElevatedButton(
                        onPressed: _calculate, child: const Text('Intentar otra vez')),
                ],
              ),
            );
          }
          if (route == null) {
            return Center(
              child: Text('No hay una ruta activa.', style: text.titleLarge),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(spokenSummary(route), style: text.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Ruta sugerida con datos de OpenStreetMap: puede haber tramos '
                'sin información. Confirma el camino al avanzar.',
                style: text.bodyMedium?.copyWith(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _speakAll(app, route),
                icon: const Icon(Icons.volume_up, size: 32),
                label: const Text('Escuchar indicaciones'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).popUntil((r) => r.isFirst),
                icon: const Icon(Icons.map, size: 32),
                label: const Text('Ver en el mapa'),
              ),
              const SizedBox(height: 24),
              Text('Paso a paso', style: text.headlineMedium),
              const SizedBox(height: 8),
              for (var i = 0; i < route.steps.length; i++)
                Semantics(
                  label: 'Paso ${i + 1}. ${spokenStep(route.steps[i])}',
                  excludeSemantics: true,
                  child: Card(
                    color: AppTheme.surface,
                    child: ListTile(
                      minTileHeight: AppTheme.minTouch,
                      leading: Icon(_stepIcon(route.steps[i].type), size: 36),
                      title: Text(route.steps[i].instruction,
                          style: text.titleLarge),
                      subtitle: route.steps[i].distanceMeters < 5
                          ? null
                          : Text(formatDistance(route.steps[i].distanceMeters),
                              style: text.bodyLarge
                                  ?.copyWith(color: AppTheme.textMuted)),
                      onTap: () => app.voice.speak(spokenStep(route.steps[i])),
                    ),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}
