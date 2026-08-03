enum AppThemeMode { light, dark, system }

enum ServiceKind { transcription, summary }

class ServiceConfig {
  const ServiceConfig({this.baseUrl = '', this.apiKey = '', this.model = ''});

  final String baseUrl;
  final String apiKey;
  final String model;

  bool get isConfigured =>
      baseUrl.trim().isNotEmpty &&
      apiKey.trim().isNotEmpty &&
      model.trim().isNotEmpty;

  ServiceConfig copyWith({String? baseUrl, String? apiKey, String? model}) =>
      ServiceConfig(
        baseUrl: baseUrl ?? this.baseUrl,
        apiKey: apiKey ?? this.apiKey,
        model: model ?? this.model,
      );

  Map<String, Object?> toPublicJson() => {'baseUrl': baseUrl, 'model': model};
}

class AppSettings {
  const AppSettings({
    this.transcription = const ServiceConfig(),
    this.summary = const ServiceConfig(),
    this.themeMode = AppThemeMode.system,
    this.imageMode = false,
    this.onboardingCompleted = false,
  });

  final ServiceConfig transcription;
  final ServiceConfig summary;
  final AppThemeMode themeMode;
  final bool imageMode;
  final bool onboardingCompleted;

  bool get servicesConfigured =>
      transcription.isConfigured && summary.isConfigured;

  AppSettings copyWith({
    ServiceConfig? transcription,
    ServiceConfig? summary,
    AppThemeMode? themeMode,
    bool? imageMode,
    bool? onboardingCompleted,
  }) => AppSettings(
    transcription: transcription ?? this.transcription,
    summary: summary ?? this.summary,
    themeMode: themeMode ?? this.themeMode,
    imageMode: imageMode ?? this.imageMode,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
  );
}
