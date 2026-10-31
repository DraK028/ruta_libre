import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/describe.dart';
import '../../core/geo.dart';
import '../../core/theme.dart';
import '../../models/report.dart';
import '../../widgets/map_markers.dart';
import '../../widgets/report_photo.dart';
import '../../widgets/ui.dart';
import 'new_report_screen.dart';

/// Detalle de un peligro reportado, con "Sigue ahí" y "Ya no está".
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, required this.reportId});

  final String reportId;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  bool _voted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = AppScope.read(context);
      final r = app.reportById(widget.reportId);
      if (r == null) return;
      app.voice.announce(
        '${describeReport(r, DateTime.now(), me: app.me, heading: app.heading)} '
        '¿Sigue ahí?',
      );
    });
  }

  Future<void> _confirm(AppState app, Report r) async {
    await app.confirmReport(r);
    setState(() => _voted = true);
    await app.voice.speak('Gracias. El reporte seguirá activo.');
  }

  Future<void> _gone(AppState app, Report r) async {
    final updated = await app.voteGone(r);
    setState(() => _voted = true);
    await app.voice.speak(updated.closed
        ? 'Gracias. El reporte se cerró.'
        : 'Gracias. Si alguien más confirma que ya no está, se cerrará.');
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final r = app.reportById(widget.reportId);
    final rl = context.rl;
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();

    if (r == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyNote('Este reporte ya no existe.',
            icon: Icons.check_circle_outline),
      );
    }

    final active = r.isActive(now);
    final me = app.me;

    Widget fact(String label, String value) => MergeSemantics(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(label,
                      style: TextStyle(fontSize: 15, color: rl.text2)),
                ),
                Text(value,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: rl.text)),
              ],
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Peligro reportado')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Row(
              children: [
                HazardTriangle(color: hazardColor(r.severity), size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(r.type.label, style: text.headlineSmall),
                  ),
                ),
                ListenButton(
                  onPressed: () => app.voice
                      .speak(describeReport(r, now, me: me, heading: app.heading)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Tag(
                  label: 'Gravedad ${r.severity.label.toLowerCase()}',
                  icon: reportIcon(r.type),
                  background: rl.hazardSoft,
                  foreground: rl.hazardText,
                ),
                if (!active)
                  Tag(
                      label: 'Ya no está activo',
                      background: rl.surface2,
                      foreground: rl.text2),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: rl.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: rl.border),
              ),
              child: Column(
                children: [
                  if (me != null)
                    fact('Dónde',
                        '${formatDistanceShort(distanceMeters(me, r.location))} '
                        '${directionFrom(me, r.location, app.heading)}'),
                  fact('Reportado', timeAgo(r.createdAt, now)),
                  fact('Confirmado', timeAgo(r.lastConfirmedAt, now)),
                  fact(active ? 'Caduca' : 'Estado',
                      active ? timeUntil(r.expiresAt, now) : 'Cerrado'),
                ],
              ),
            ),
            if (r.note.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('“${r.note}”',
                  style: TextStyle(fontSize: 17, height: 1.4, color: rl.text)),
            ],
            if (ReportPhoto.exists(r.photoPath)) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ReportPhoto(path: r.photoPath!, height: 220),
              ),
            ],
            if (active) ...[
              const SizedBox(height: 24),
              Semantics(
                header: true,
                child: Text('¿Sigue ahí?', style: text.titleLarge),
              ),
              const SizedBox(height: 4),
              Text('Tu respuesta mantiene el mapa al día para los demás.',
                  style: TextStyle(fontSize: 15, color: rl.text2)),
              const SizedBox(height: 12),
              if (_voted)
                Semantics(
                  liveRegion: true,
                  child: Text('Gracias por confirmar.',
                      style: TextStyle(fontSize: 17, color: rl.okText)),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.hazard,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _confirm(app, r),
                        child: const Text('Sigue ahí'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(56)),
                        onPressed: () => _gone(app, r),
                        child: const Text('Ya no está'),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
