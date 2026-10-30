import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Habla (texto a voz) y escucha (voz a texto) en español de México.
class VoiceService {
  VoiceService({FlutterTts? tts, SpeechToText? stt})
      : _tts = tts ?? FlutterTts(),
        _stt = stt ?? SpeechToText();

  static const _language = 'es-MX';

  final FlutterTts _tts;
  final SpeechToText _stt;

  bool _sttReady = false;
  String? _sttLocaleId;

  /// Si es falso, [announce] no dice nada (el usuario lo desactivó).
  bool guidanceEnabled = true;

  /// Indica si el micrófono está escuchando, para que la UI lo muestre.
  final ValueNotifier<bool> listening = ValueNotifier(false);

  Future<void> init({required double speechRate}) async {
    // Cada ajuste va por separado: si un motor de voz (o el navegador) no
    // soporta uno, los demás siguen aplicando y la app no se detiene.
    Future<void> attempt(Future<Object?> Function() call) async {
      try {
        await call();
      } catch (e) {
        debugPrint('Ajuste de voz no soportado: $e');
      }
    }

    // Si es-MX no está instalado, el motor usa su español por defecto.
    var language = 'es-ES';
    await attempt(() async {
      if (await _tts.isLanguageAvailable(_language) == true) language = _language;
      return null;
    });
    await attempt(() => _tts.setLanguage(language));
    await attempt(() => _tts.setSpeechRate(speechRate));
    await attempt(() => _tts.setVolume(1.0));
    await attempt(() => _tts.awaitSpeakCompletion(true));
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      await attempt(() => _tts.setSharedInstance(true));
    }
  }

  Future<void> setSpeechRate(double rate) => _tts.setSpeechRate(rate);

  /// Lee siempre en voz alta, interrumpiendo lo anterior.
  ///
  /// Espera a que termine de hablar, pero con un tope: en algunos navegadores
  /// el motor de voz nunca avisa que terminó y la app no debe quedarse
  /// detenida por eso.
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    // ~70 ms por letra en voz pausada, entre 3 y 30 segundos.
    final limit = Duration(
        milliseconds: (text.length * 70).clamp(3000, 30000).toInt());
    try {
      await _tts.stop().timeout(const Duration(seconds: 2));
      await _tts.speak(text).timeout(limit);
    } on TimeoutException {
      // Se sigue: la voz puede seguir sonando, pero la app no se bloquea.
    } catch (e) {
      debugPrint('No se pudo hablar: $e');
    }
  }

  /// Anuncios de navegación: solo si la guía por voz está activa.
  Future<void> announce(String text) async {
    if (guidanceEnabled) await speak(text);
  }

  Future<void> stop() => _tts.stop();

  /// Escucha una frase y la devuelve, o null si no se entendió nada.
  Future<String?> listenOnce({
    Duration maxDuration = const Duration(seconds: 8),
  }) async {
    if (!_sttReady) {
      try {
        _sttReady = await _stt.initialize();
      } catch (e) {
        debugPrint('Reconocimiento de voz no disponible: $e');
        _sttReady = false;
      }
      if (!_sttReady) return null;
      final locales = await _stt.locales();
      final spanish = locales.where((l) => l.localeId.startsWith('es'));
      _sttLocaleId = spanish
          .firstWhere(
            (l) => l.localeId.replaceAll('-', '_') == 'es_MX',
            orElse: () => spanish.isNotEmpty
                ? spanish.first
                : LocaleName(_language, 'Español'),
          )
          .localeId;
    }

    await _tts.stop();
    await HapticFeedback.mediumImpact();

    String? finalWords;
    listening.value = true;
    await _stt.listen(
      onResult: (result) {
        if (result.finalResult) finalWords = result.recognizedWords;
      },
      listenOptions: SpeechListenOptions(
        localeId: _sttLocaleId,
        listenFor: maxDuration,
        pauseFor: const Duration(seconds: 3),
        partialResults: false,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      ),
    );

    // Espera a que el reconocedor termine (por pausa, tiempo o error).
    final deadline = DateTime.now().add(maxDuration + const Duration(seconds: 2));
    while (_stt.isListening && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    await _stt.stop();
    // El resultado final puede llegar justo después de detenerse.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    listening.value = false;

    final words = finalWords?.trim();
    return (words == null || words.isEmpty) ? null : words;
  }

  void dispose() {
    _tts.stop();
    _stt.cancel();
    listening.dispose();
  }
}
