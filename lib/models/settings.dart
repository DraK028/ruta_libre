/// Cómo se mueve la persona. Cambia rutas, filtros y guía por voz.
enum MobilityProfile {
  wheelchair(
    'Silla de ruedas',
    'Entradas sin escalón, rampas y pendientes suaves',
    orsProfile: 'wheelchair',
    avoidSteps: true,
    voiceByDefault: false,
  ),
  mobilityAid(
    'Bastón o andadera',
    'Evitar escaleras y pisos irregulares',
    orsProfile: 'foot-walking',
    avoidSteps: true,
    voiceByDefault: false,
  ),
  lowVision(
    'Baja visión',
    'Letra grande, alto contraste y avisos de peligros',
    orsProfile: 'foot-walking',
    avoidSteps: false,
    voiceByDefault: true,
  ),
  blind(
    'Ceguera',
    'Todo por voz: qué hay cerca, peligros y rutas',
    orsProfile: 'foot-walking',
    avoidSteps: false,
    voiceByDefault: true,
  );

  const MobilityProfile(
    this.label,
    this.description, {
    required this.orsProfile,
    required this.avoidSteps,
    required this.voiceByDefault,
  });

  final String label;
  final String description;

  /// Perfil de openrouteservice para calcular rutas.
  final String orsProfile;
  final bool avoidSteps;
  final bool voiceByDefault;

  /// Quienes usan silla de ruedas solo ven en el mapa lo accesible por defecto.
  bool get onlyAccessibleByDefault => this == MobilityProfile.wheelchair;
}

class AppSettings {
  const AppSettings({
    this.profile,
    this.voiceGuidance = true,
    this.hazardAlerts = true,
    this.onlyAccessible = false,
    this.speechRate = 0.5,
    this.textScale = 1.2,
    this.orsApiKey = '',
  });

  /// Null hasta que la persona elige su perfil la primera vez.
  final MobilityProfile? profile;
  final bool voiceGuidance;

  /// Aviso por voz y vibración al acercarse a un peligro reportado.
  final bool hazardAlerts;

  /// Ocultar en el mapa lo que no es accesible o no tiene dato.
  final bool onlyAccessible;
  final double speechRate;
  final double textScale;

  /// Clave de openrouteservice escrita por la persona (se guarda solo en
  /// este dispositivo). Si está vacía se usa la de compilación, si hay.
  final String orsApiKey;

  AppSettings copyWith({
    MobilityProfile? profile,
    bool? voiceGuidance,
    bool? hazardAlerts,
    bool? onlyAccessible,
    double? speechRate,
    double? textScale,
    String? orsApiKey,
  }) =>
      AppSettings(
        profile: profile ?? this.profile,
        voiceGuidance: voiceGuidance ?? this.voiceGuidance,
        hazardAlerts: hazardAlerts ?? this.hazardAlerts,
        onlyAccessible: onlyAccessible ?? this.onlyAccessible,
        speechRate: speechRate ?? this.speechRate,
        textScale: textScale ?? this.textScale,
        orsApiKey: orsApiKey ?? this.orsApiKey,
      );

  Map<String, Object?> toJson() => {
        'profile': profile?.name,
        'voiceGuidance': voiceGuidance,
        'hazardAlerts': hazardAlerts,
        'onlyAccessible': onlyAccessible,
        'speechRate': speechRate,
        'textScale': textScale,
        'orsApiKey': orsApiKey,
      };

  factory AppSettings.fromJson(Map<String, Object?> json) {
    final profile = json['profile'] as String?;
    return AppSettings(
      profile: profile == null ? null : MobilityProfile.values.byName(profile),
      voiceGuidance: (json['voiceGuidance'] as bool?) ?? true,
      hazardAlerts: (json['hazardAlerts'] as bool?) ?? true,
      onlyAccessible: (json['onlyAccessible'] as bool?) ?? false,
      speechRate: (json['speechRate'] as num?)?.toDouble() ?? 0.5,
      textScale: (json['textScale'] as num?)?.toDouble() ?? 1.2,
      orsApiKey: (json['orsApiKey'] as String?) ?? '',
    );
  }
}
