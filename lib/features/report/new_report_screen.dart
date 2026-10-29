import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../app_state.dart';
import '../../core/theme.dart';
import '../../models/report.dart';
import '../../widgets/report_photo.dart';

/// Reportar un peligro en tres toques: tipo, gravedad y enviar.
///
/// La ubicación sale del GPS; foto y nota son opcionales.
class NewReportScreen extends StatefulWidget {
  const NewReportScreen({super.key});

  @override
  State<NewReportScreen> createState() => _NewReportScreenState();
}

class _NewReportScreenState extends State<NewReportScreen> {
  ReportType? _type;
  Severity _severity = Severity.medium;
  final _note = TextEditingController();
  String? _photoPath;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppScope.read(context).voice.announce(
            'Reportar peligro. Elige qué encontraste. '
            'Se usará tu ubicación actual.',
          );
    });
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _pickType(ReportType t) {
    HapticFeedback.selectionClick();
    setState(() {
      _type = t;
      _severity = t.defaultSeverity;
    });
    AppScope.read(context).voice.announce(
          '${t.label}. Gravedad ${t.defaultSeverity.label.toLowerCase()}. '
          'Puedes cambiarla, agregar foto o tocar Enviar reporte.',
        );
  }

  Future<void> _takePhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1280,
      imageQuality: 70,
    );
    if (picked == null) return;
    final String dest;
    if (kIsWeb) {
      // En web es una URL temporal del navegador.
      dest = picked.path;
    } else {
      // La cámara guarda en caché; se copia para que no se borre.
      final dir = await getApplicationDocumentsDirectory();
      dest = '${dir.path}/reporte_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(picked.path).copy(dest);
    }
    if (!mounted) return;
    setState(() => _photoPath = dest);
    await AppScope.read(context).voice.announce('Foto agregada.');
  }

  Future<void> _send() async {
    final app = AppScope.read(context);
    final type = _type;
    final here = app.me;
    if (type == null) return;
    if (here == null) {
      await app.voice.speak(
          'Todavía no tengo tu ubicación. Revisa que el GPS esté encendido.');
      return;
    }
    setState(() => _sending = true);
    await app.addReport(
      type: type,
      severity: _severity,
      at: here,
      note: _note.text.trim(),
      photoPath: _photoPath,
    );
    await HapticFeedback.heavyImpact();
    await app.voice.speak(
        'Reporte enviado: ${type.label}. Gracias por avisar a los demás.');
    if (mounted) Navigator.of(context).pop();
  }

  IconData _icon(ReportType t) => switch (t) {
        ReportType.blockedRamp => Icons.car_crash,
        ReportType.openDrain => Icons.circle_outlined,
        ReportType.brokenSidewalk => Icons.broken_image,
        ReportType.construction => Icons.construction,
        ReportType.noRamp => Icons.stairs,
        ReportType.elevatorOut => Icons.elevator,
        ReportType.flooding => Icons.water,
        ReportType.other => Icons.warning,
      };

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final text = Theme.of(context).textTheme;
    final accuracy = app.location.accuracy;

    return Scaffold(
      appBar: AppBar(title: const Text('Reportar peligro')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              app.me == null
                  ? 'Buscando tu ubicación…'
                  : 'Se reportará donde estás'
                      '${accuracy == null ? '' : ' (precisión de ${accuracy.round()} m)'}.',
              style: text.bodyLarge?.copyWith(
                  color: app.me == null ? AppTheme.danger : AppTheme.textMuted),
            ),
            const SizedBox(height: 16),
            Text('1. ¿Qué encontraste?', style: text.headlineMedium),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.25,
              children: [
                for (final t in ReportType.values)
                  _TypeButton(
                    icon: _icon(t),
                    label: t.label,
                    selected: _type == t,
                    onTap: () => _pickType(t),
                  ),
              ],
            ),
            if (_type != null) ...[
              const SizedBox(height: 24),
              Text('2. Gravedad', style: text.headlineMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final s in Severity.values) ...[
                    Expanded(
                      child: Semantics(
                        selected: _severity == s,
                        button: true,
                        label: 'Gravedad ${s.label}',
                        excludeSemantics: true,
                        child: _severity == s
                            ? ElevatedButton(
                                onPressed: () => setState(() => _severity = s),
                                child: Text(s.label))
                            : OutlinedButton(
                                onPressed: () => setState(() => _severity = s),
                                child: Text(s.label)),
                      ),
                    ),
                    if (s != Severity.values.last) const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              Text('3. Opcional', style: text.headlineMedium),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _sending ? null : _takePhoto,
                icon: Icon(_photoPath == null ? Icons.photo_camera : Icons.check,
                    size: 30),
                label: Text(_photoPath == null ? 'Agregar foto' : 'Foto agregada'),
              ),
              if (_photoPath != null) ...[
                const SizedBox(height: 8),
                ReportPhoto(path: _photoPath!, height: 180),
              ],
              const SizedBox(height: 8),
              Text(
                'Evita que salgan rostros o placas en la foto.',
                style: text.bodyMedium?.copyWith(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _note,
                style: text.bodyLarge,
                maxLines: 2,
                maxLength: 140,
                decoration: const InputDecoration(
                  labelText: 'Nota (ej. frente a la farmacia)',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 96,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.danger,
                    foregroundColor: AppTheme.onAccent,
                  ),
                  onPressed: _sending || app.me == null ? null : _send,
                  icon: const Icon(Icons.send, size: 36),
                  label: Text(_sending ? 'Enviando…' : 'Enviar reporte',
                      style: const TextStyle(fontSize: 26)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppTheme.onAccent : AppTheme.text;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppTheme.accent : AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: selected ? AppTheme.accent : AppTheme.textMuted,
                  width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: selected ? fg : AppTheme.accent),
                const SizedBox(height: 6),
                Text(label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700, color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
