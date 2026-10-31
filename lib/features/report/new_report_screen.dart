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
import '../../widgets/ui.dart';

/// "6 horas", "3 días".
String formatTtl(Duration d) {
  if (d.inHours < 24) return d.inHours == 1 ? '1 hora' : '${d.inHours} horas';
  return d.inDays == 1 ? '1 día' : '${d.inDays} días';
}

IconData reportIcon(ReportType t) => switch (t) {
      ReportType.blockedRamp => Icons.directions_car_outlined,
      ReportType.openDrain => Icons.blur_circular,
      ReportType.brokenSidewalk => Icons.timeline,
      ReportType.construction => Icons.construction,
      ReportType.noRamp => Icons.stairs_outlined,
      ReportType.elevatorOut => Icons.elevator_outlined,
      ReportType.flooding => Icons.water_drop_outlined,
      ReportType.other => Icons.error_outline,
    };

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

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final rl = context.rl;
    final text = Theme.of(context).textTheme;
    final accuracy = app.location.accuracy;
    final type = _type;
    final canSend = type != null && app.me != null && !_sending;

    Widget heading(String s) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Semantics(
            header: true,
            child: Text(s,
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700, color: rl.text)),
          ),
        );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Cerrar',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: const Text('Reportar peligro'),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                children: [
                  MergeSemantics(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: rl.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: rl.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: app.me == null
                                  ? rl.hazardSoft
                                  : rl.primarySoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                                app.me == null
                                    ? Icons.location_searching
                                    : Icons.location_on_outlined,
                                color: app.me == null
                                    ? rl.hazardText
                                    : rl.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    app.me == null
                                        ? 'Buscando tu ubicación…'
                                        : 'Se reportará donde estás',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: rl.text)),
                                Text(
                                    app.me == null
                                        ? 'Revisa que el GPS esté encendido'
                                        : 'Ubicación por GPS'
                                            '${accuracy == null ? '' : ' · precisión ${accuracy.round()} m'}',
                                    style: TextStyle(
                                        fontSize: 14, color: rl.text2)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  heading('¿Qué encontraste?'),
                  LayoutBuilder(builder: (context, c) {
                    final w = (c.maxWidth - 10) / 2;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final t in ReportType.values)
                          SizedBox(
                            width: w,
                            child: _TypeOption(
                              icon: reportIcon(t),
                              label: t.label,
                              selected: _type == t,
                              onTap: () => _pickType(t),
                            ),
                          ),
                      ],
                    );
                  }),
                  const SizedBox(height: 20),
                  heading('Gravedad'),
                  Segmented<Severity>(
                    values: Severity.values,
                    selected: _severity,
                    labelOf: (s) => s.label,
                    semanticPrefix: 'Gravedad ',
                    onChanged: (s) {
                      HapticFeedback.selectionClick();
                      setState(() => _severity = s);
                    },
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: rl.text2),
                      textStyle:
                          const TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                    ),
                    onPressed: _sending ? null : _takePhoto,
                    icon: Icon(_photoPath == null
                        ? Icons.photo_camera_outlined
                        : Icons.check),
                    label: Text(_photoPath == null
                        ? 'Agregar foto (opcional)'
                        : 'Cambiar foto'),
                  ),
                  if (_photoPath != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: ReportPhoto(path: _photoPath!, height: 180),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text('Evita que salgan rostros o placas en la foto.',
                      style: TextStyle(fontSize: 14, color: rl.text2)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _note,
                    style: text.bodyLarge,
                    maxLines: 2,
                    maxLength: 140,
                    decoration: const InputDecoration(
                      labelText: 'Nota (opcional)',
                      hintText: 'Ej. frente a la farmacia',
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(top: BorderSide(color: rl.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.hazard,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: canSend ? _send : null,
                    child: Text(_sending
                        ? 'Enviando…'
                        : (type == null ? 'Elige qué encontraste' : 'Enviar reporte')),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    type == null
                        ? 'Los reportes caducan solos si nadie confirma que siguen ahí'
                        : 'Caduca en ${formatTtl(type.ttl)} si nadie confirma que sigue ahí',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: rl.text2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
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
    final rl = context.rl;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? rl.hazardSoft : rl.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? AppTheme.hazard : rl.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon,
                    size: 22, color: selected ? AppTheme.hazard : rl.text),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.2,
                        color: selected ? rl.hazardText : rl.text,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w400,
                      )),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
