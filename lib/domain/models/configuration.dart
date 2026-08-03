enum AppThemeMode { light, dark, system }

enum ServiceKind { realtimeTranscription, fileTranscription, summary }

enum RealtimeProtocolSetting { openAiRealtime, disabled }

class ServiceConfig {
  const ServiceConfig({
    this.baseUrl = '',
    this.model = '',
    this.secretReference = '',
    this.hasApiKey = false,
    this.apiKey = '',
  });

  final String baseUrl;
  final String apiKey;
  final String model;
  final String secretReference;
  final bool hasApiKey;

  bool get isConfigured =>
      baseUrl.trim().isNotEmpty &&
      (hasApiKey || apiKey.trim().isNotEmpty) &&
      model.trim().isNotEmpty;

  ServiceConfig copyWith({
    String? baseUrl,
    String? apiKey,
    String? model,
    String? secretReference,
    bool? hasApiKey,
  }) => ServiceConfig(
    baseUrl: baseUrl ?? this.baseUrl,
    apiKey: apiKey ?? this.apiKey,
    model: model ?? this.model,
    secretReference: secretReference ?? this.secretReference,
    hasApiKey: hasApiKey ?? this.hasApiKey,
  );

  Map<String, Object?> toPublicJson() => {'baseUrl': baseUrl, 'model': model};
}

class RealtimeServiceConfig {
  const RealtimeServiceConfig({
    this.websocketUrl = '',
    this.model = '',
    this.protocol = RealtimeProtocolSetting.openAiRealtime,
    this.enabled = false,
    this.uploadConsentGranted = false,
    this.hasApiKey = false,
    this.language = 'auto',
    this.keywords = const <String>[],
    this.contextPrompt = '',
  });

  static const secretReference = 'service.realtime.apiKey';

  final String websocketUrl;
  final String model;
  final RealtimeProtocolSetting protocol;
  final bool enabled;
  final bool uploadConsentGranted;
  final bool hasApiKey;
  final String language;
  final List<String> keywords;
  final String contextPrompt;

  bool get isConfigured =>
      protocol != RealtimeProtocolSetting.disabled &&
      websocketUrl.trim().isNotEmpty &&
      model.trim().isNotEmpty &&
      hasApiKey;

  bool get canStream => enabled && uploadConsentGranted && isConfigured;

  RealtimeServiceConfig copyWith({
    String? websocketUrl,
    String? model,
    RealtimeProtocolSetting? protocol,
    bool? enabled,
    bool? uploadConsentGranted,
    bool? hasApiKey,
    String? language,
    List<String>? keywords,
    String? contextPrompt,
  }) => RealtimeServiceConfig(
    websocketUrl: websocketUrl ?? this.websocketUrl,
    model: model ?? this.model,
    protocol: protocol ?? this.protocol,
    enabled: enabled ?? this.enabled,
    uploadConsentGranted: uploadConsentGranted ?? this.uploadConsentGranted,
    hasApiKey: hasApiKey ?? this.hasApiKey,
    language: language ?? this.language,
    keywords: keywords ?? this.keywords,
    contextPrompt: contextPrompt ?? this.contextPrompt,
  );

  Map<String, Object?> toPublicJson() => {
    'websocketUrl': websocketUrl,
    'model': model,
    'protocol': protocol.name,
    'enabled': enabled,
    'uploadConsentGranted': uploadConsentGranted,
    'hasApiKey': hasApiKey,
    'language': language,
    'keywords': keywords,
    'contextPrompt': contextPrompt,
  };
}

class AppSettings {
  const AppSettings({
    this.realtimeTranscription = const RealtimeServiceConfig(),
    this.transcription = const ServiceConfig(),
    this.summary = const ServiceConfig(),
    this.themeMode = AppThemeMode.system,
    this.imageMode = false,
    this.onboardingCompleted = false,
  });

  final RealtimeServiceConfig realtimeTranscription;
  final ServiceConfig transcription;
  final ServiceConfig summary;
  final AppThemeMode themeMode;
  final bool imageMode;
  final bool onboardingCompleted;

  bool get servicesConfigured =>
      transcription.isConfigured && summary.isConfigured;

  AppSettings copyWith({
    RealtimeServiceConfig? realtimeTranscription,
    ServiceConfig? transcription,
    ServiceConfig? summary,
    AppThemeMode? themeMode,
    bool? imageMode,
    bool? onboardingCompleted,
  }) => AppSettings(
    realtimeTranscription: realtimeTranscription ?? this.realtimeTranscription,
    transcription: transcription ?? this.transcription,
    summary: summary ?? this.summary,
    themeMode: themeMode ?? this.themeMode,
    imageMode: imageMode ?? this.imageMode,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
  );
}
