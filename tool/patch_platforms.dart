// Aplica la configuración nativa que Ruta Libre necesita, después de generar
// las carpetas android/ e ios/ con `flutter create`.
//
// Uso (desde la raíz del proyecto):
//   flutter create --org com.drak028 --project-name ruta_libre --platforms android,ios .
//   dart run tool/patch_platforms.dart
//
// Es seguro correrlo varias veces: cada cambio revisa si ya existe.
import 'dart:io';

const _marker = 'ruta-libre-patch';

void main() {
  for (final line in [
    _patchAndroidManifest(),
    _patchAndroidGradle(),
    _patchInfoPlist(),
  ]) {
    stdout.writeln(line);
  }
}

String _patchAndroidManifest() {
  final file = File('android/app/src/main/AndroidManifest.xml');
  if (!file.existsSync()) {
    return '✗ No existe ${file.path}: corre flutter create primero.';
  }
  var xml = file.readAsStringSync();
  if (xml.contains(_marker)) return '• AndroidManifest.xml ya estaba listo.';

  // Sin permiso CAMERA a propósito: image_picker usa la app de cámara del
  // sistema, y declararlo obligaría a pedirlo en tiempo de ejecución.
  const permissions = '''
    <!-- $_marker: permisos -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
''';

  const queries = '''
        <!-- $_marker: servicios y apps que usa Ruta Libre -->
        <intent>
            <action android:name="android.intent.action.TTS_SERVICE" />
        </intent>
        <intent>
            <action android:name="android.speech.RecognitionService" />
        </intent>
        <intent>
            <action android:name="android.media.action.IMAGE_CAPTURE" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
''';

  final open = RegExp(r'<manifest[^>]*>').firstMatch(xml);
  if (open == null) return '✗ AndroidManifest.xml sin etiqueta <manifest>.';
  xml = xml.replaceRange(open.end, open.end, '\n$permissions');
  xml = xml.contains('<queries>')
      ? xml.replaceFirst('<queries>', '<queries>\n$queries')
      : xml.replaceFirst(
          '</manifest>', '    <queries>\n$queries    </queries>\n</manifest>');
  file.writeAsStringSync(xml);
  return '✓ AndroidManifest.xml: ubicación, micrófono, internet y consultas.';
}

String _patchAndroidGradle() {
  final kts = File('android/app/build.gradle.kts');
  final groovy = File('android/app/build.gradle');
  final file = kts.existsSync() ? kts : groovy;
  if (!file.existsSync()) return '✗ No existe android/app/build.gradle(.kts).';
  var src = file.readAsStringSync();
  if (src.contains('maxOf(24') || src.contains('Math.max(24')) {
    return '• ${file.path} ya estaba listo.';
  }
  // image_picker pide Android 7.0 (API 24) o superior.
  final before = src;
  src = file == kts
      ? src.replaceFirst('minSdk = flutter.minSdkVersion',
          'minSdk = maxOf(24, flutter.minSdkVersion) // $_marker')
      : src.replaceFirst('minSdkVersion flutter.minSdkVersion',
          'minSdkVersion Math.max(24, flutter.minSdkVersion) // $_marker');
  if (src == before) {
    return '✗ ${file.path}: no encontré minSdk; ponlo en 24 a mano.';
  }
  file.writeAsStringSync(src);
  return '✓ ${file.path}: minSdk 24.';
}

String _patchInfoPlist() {
  final file = File('ios/Runner/Info.plist');
  if (!file.existsSync()) return '✗ No existe ios/Runner/Info.plist.';
  var plist = file.readAsStringSync();
  if (plist.contains(_marker)) return '• Info.plist ya estaba listo.';

  const entries = '''
	<!-- $_marker -->
	<key>NSLocationWhenInUseUsageDescription</key>
	<string>Ruta Libre usa tu ubicación para decirte qué lugares accesibles y peligros hay cerca.</string>
	<key>NSCameraUsageDescription</key>
	<string>Ruta Libre usa la cámara para que agregues una foto al reportar un peligro.</string>
	<key>NSPhotoLibraryUsageDescription</key>
	<string>Ruta Libre guarda la foto del peligro que reportas.</string>
	<key>NSMicrophoneUsageDescription</key>
	<string>Ruta Libre usa el micrófono para entender lo que le pides por voz.</string>
	<key>NSSpeechRecognitionUsageDescription</key>
	<string>Ruta Libre convierte tu voz en comandos como qué hay cerca o reportar.</string>
	<key>LSApplicationQueriesSchemes</key>
	<array>
		<string>https</string>
	</array>
''';
  final closing = plist.lastIndexOf('</dict>');
  if (closing == -1) return '✗ Info.plist sin </dict> final.';
  plist = plist.replaceRange(closing, closing, entries);
  file.writeAsStringSync(plist);
  return '✓ Info.plist: textos de permisos.';
}
