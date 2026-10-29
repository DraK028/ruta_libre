import 'text_utils.dart';

/// Acciones que se pueden pedir por voz desde el mapa.
enum VoiceCommand { nearby, report, whereAmI, clearRoute, settings, unknown }

const _keywords = <VoiceCommand, List<String>>{
  // Reportar va primero: "hay un peligro cerca" es un reporte, no una consulta.
  VoiceCommand.report: ['reportar', 'reporta', 'peligro', 'obstaculo', 'avisar'],
  VoiceCommand.clearRoute: ['quitar ruta', 'cancelar ruta', 'borrar ruta'],
  VoiceCommand.whereAmI: ['donde estoy', 'mi ubicacion'],
  VoiceCommand.nearby: [
    'cerca',
    'que hay',
    'alrededor',
    'lugares',
    'buscar',
    'farmacia',
    'bano',
  ],
  VoiceCommand.settings: ['ajuste', 'configuracion', 'perfil'],
};

/// Convierte una frase reconocida en un comando, sin importar acentos.
VoiceCommand parseVoiceCommand(String phrase) {
  final text = normalize(phrase);
  if (text.isEmpty) return VoiceCommand.unknown;
  for (final entry in _keywords.entries) {
    for (final word in entry.value) {
      if (text.contains(word)) return entry.key;
    }
  }
  return VoiceCommand.unknown;
}
