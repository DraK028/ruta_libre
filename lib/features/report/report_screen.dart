import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../core/describe.dart';
import '../../core/theme.dart';
import '../../models/report.dart';
import '../../widgets/report_photo.dart';

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
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();

    if (r == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text('Este reporte ya no existe.', style: text.titleLarge),
        ),
      );
    }

    final active = r.isActive(now);
    final where = whereIs(r.location, app.me, app.heading);

    return Scaffold(
      appBar: AppBar(title: const Text('Peligro reportado')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Icon(Icons.warning,
                    size: 64,
                    color: r.severity == Severity.high
                        ? AppTheme.hazard
                        : AppTheme.accessLimited),
                const SizedBox(width: 16),
                Expanded(child: Text(r.type.label, style: text.headlineMedium)),
              ],
            ),
            const SizedBox(height: 12),
            Text('Gravedad ${r.severity.label.toLowerCase()}',
                style: text.titleLarge),
            if (where.isNotEmpty) Text(where, style: text.titleLarge),
            const SizedBox(height: 12),
            Text('Reportado ${timeAgo(r.createdAt, now)}', style: text.bodyLarge),
            Text('Confirmado ${timeAgo(r.lastConfirmedAt, now)}',
                style: text.bodyLarge),
            Text(
              active
                  ? 'Caduca ${timeUntil(r.expiresAt, now)} si nadie lo confirma'
                  : 'Este reporte ya no está activo',
              style: text.bodyLarge?.copyWith(color: AppTheme.textMuted),
            ),
            if (r.note.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('“${r.note}”', style: text.titleLarge),
            ],
            if (ReportPhoto.exists(r.photoPath)) ...[
              const SizedBox(height: 16),
              ReportPhoto(path: r.photoPath!, height: 220),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => app.voice.speak(
                  describeReport(r, now, me: app.me, heading: app.heading)),
              icon: const Icon(Icons.volume_up, size: 32),
              label: const Text('Escuchar'),
            ),
            if (active) ...[
              const SizedBox(height: 24),
              Text('¿Sigue ahí?', style: text.headlineMedium),
              const SizedBox(height: 12),
              if (_voted)
                Text('Gracias por confirmar.',
                    style: text.titleLarge?.copyWith(color: AppTheme.success))
              else
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _confirm(app, r),
                        child: const Text('Sigue ahí'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
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
