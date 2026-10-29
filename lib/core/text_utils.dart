/// Utilidades de texto sin dependencias de Flutter (fáciles de probar).
library;

const _accents = {
  'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
};

/// Minúsculas y sin acentos: "Medicinas Ñ" -> "medicinas n".
String normalize(String input) {
  final lower = input.toLowerCase().trim();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    buffer.write(_accents[ch] ?? ch);
  }
  return buffer.toString();
}

/// "PARACETAMOL" -> "Paracetamol"; "ácido acetilsalicílico" -> "Ácido Acetilsalicílico".
String titleCase(String input) {
  return input
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}

/// Junta las líneas del OCR en un texto natural para leer en voz alta:
/// une palabras cortadas con guion y quita espacios repetidos.
String cleanForSpeech(String raw) {
  return raw
      .replaceAll(RegExp(r'-\n'), '')
      .replaceAll(RegExp(r'[ \t]+'), ' ')
      .replaceAll(RegExp(r'\n{2,}'), '\n')
      .trim();
}
