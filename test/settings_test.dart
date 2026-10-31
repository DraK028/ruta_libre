import 'package:flutter_test/flutter_test.dart';
import 'package:ruta_libre/models/settings.dart';

void main() {
  test('ajustes nuevos tienen valores por defecto seguros', () {
    final s = AppSettings.fromJson(const {});
    expect(s.backgroundLocation, isTrue);
    expect(s.hazardAlerts, isTrue);
    expect(s.theme, ThemePreference.system);
    expect(s.profile, isNull);
  });

  test('ajustes sobreviven ida y vuelta por JSON', () {
    const s = AppSettings(
      profile: MobilityProfile.blind,
      backgroundLocation: false,
      theme: ThemePreference.dark,
      textScale: 1.6,
    );
    final back = AppSettings.fromJson(s.toJson());
    expect(back.profile, MobilityProfile.blind);
    expect(back.backgroundLocation, isFalse);
    expect(back.theme, ThemePreference.dark);
    expect(back.textScale, 1.6);
  });
}
