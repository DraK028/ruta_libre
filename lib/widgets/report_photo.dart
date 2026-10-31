import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Foto de un reporte en el teléfono (archivo) o en web (URL del navegador).
///
/// En web la foto vive solo mientras la pestaña está abierta; si ya no
/// existe se muestra un aviso en vez de fallar.
class ReportPhoto extends StatelessWidget {
  const ReportPhoto({super.key, required this.path, this.height = 200});

  final String path;
  final double height;

  /// Si hay algo que mostrar en esta plataforma.
  static bool exists(String? path) {
    if (path == null || path.isEmpty) return false;
    if (kIsWeb) return true;
    return File(path).existsSync();
  }

  @override
  Widget build(BuildContext context) {
    Widget missing(BuildContext _, Object _, StackTrace? _) => SizedBox(
          height: 80,
          child: Center(
            child: Text('La foto ya no está disponible.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: context.rl.text2)),
          ),
        );

    final image = kIsWeb
        ? Image.network(path,
            height: height,
            fit: BoxFit.cover,
            semanticLabel: 'Foto del peligro',
            errorBuilder: missing)
        : Image.file(File(path),
            height: height,
            fit: BoxFit.cover,
            semanticLabel: 'Foto del peligro',
            errorBuilder: missing);

    return ClipRRect(borderRadius: BorderRadius.circular(12), child: image);
  }
}
