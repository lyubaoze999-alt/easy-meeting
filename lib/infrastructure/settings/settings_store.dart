import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/configuration.dart';
import '../../domain/realtime/realtime_transcription_client.dart';

class SettingsStore implements RealtimeSecretProvider {
  SettingsStore({FlutterSecureStorage? secureStorage, this._preferences})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const transcriptionSecretReference = 'service.transcription.apiKey';
  static const _realtimeKey = RealtimeServiceConfig.secretReference;
  static const summarySecretReference = 'service.summary.apiKey';
  final FlutterSecureStorage _secureStorage;
  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  Future<AppSettings> load() async {
    final prefs = await _prefs;
    final realtimeSecret = await _secureStorage.read(key: _realtimeKey);
    final transcriptionSecret = await _secureStorage.read(
      key: transcriptionSecretReference,
    );
    final summarySecret = await _secureStorage.read(
      key: summarySecretReference,
    );
    return AppSettings(
      realtimeTranscription: RealtimeServiceConfig(
        websocketUrl: prefs.getString('realtime.websocketUrl') ?? '',
        model: prefs.getString('realtime.model') ?? '',
        protocol: RealtimeProtocolSetting.values.byName(
          prefs.getString('realtime.protocol') ??
              RealtimeProtocolSetting.openAiRealtime.name,
        ),
        enabled: prefs.getBool('realtime.enabled') ?? false,
        uploadConsentGranted:
            prefs.getBool('realtime.uploadConsentGranted') ?? false,
        hasApiKey: realtimeSecret?.isNotEmpty ?? false,
        language: prefs.getString('realtime.language') ?? 'auto',
        keywords: prefs.getStringList('realtime.keywords') ?? const <String>[],
        contextPrompt: prefs.getString('realtime.contextPrompt') ?? '',
      ),
      transcription: ServiceConfig(
        baseUrl: prefs.getString('transcription.baseUrl') ?? '',
        model: prefs.getString('transcription.model') ?? '',
        secretReference: transcriptionSecretReference,
        hasApiKey: transcriptionSecret?.isNotEmpty ?? false,
      ),
      summary: ServiceConfig(
        baseUrl: prefs.getString('summary.baseUrl') ?? '',
        model: prefs.getString('summary.model') ?? '',
        secretReference: summarySecretReference,
        hasApiKey: summarySecret?.isNotEmpty ?? false,
      ),
      themeMode: AppThemeMode.values.byName(
        prefs.getString('appearance.theme') ?? AppThemeMode.system.name,
      ),
      imageMode: prefs.getBool('summary.imageMode') ?? false,
      onboardingCompleted: prefs.getBool('onboarding.completed') ?? false,
    );
  }

  Future<void> save(
    AppSettings settings, {
    String? realtimeApiKey,
    String? transcriptionApiKey,
    String? summaryApiKey,
  }) async {
    final prefs = await _prefs;
    await Future.wait([
      prefs.setString(
        'realtime.websocketUrl',
        settings.realtimeTranscription.websocketUrl,
      ),
      prefs.setString('realtime.model', settings.realtimeTranscription.model),
      prefs.setString(
        'realtime.protocol',
        settings.realtimeTranscription.protocol.name,
      ),
      prefs.setBool('realtime.enabled', settings.realtimeTranscription.enabled),
      prefs.setBool(
        'realtime.uploadConsentGranted',
        settings.realtimeTranscription.uploadConsentGranted,
      ),
      prefs.setString(
        'realtime.language',
        settings.realtimeTranscription.language,
      ),
      prefs.setStringList(
        'realtime.keywords',
        settings.realtimeTranscription.keywords,
      ),
      prefs.setString(
        'realtime.contextPrompt',
        settings.realtimeTranscription.contextPrompt,
      ),
      prefs.setString('transcription.baseUrl', settings.transcription.baseUrl),
      prefs.setString('transcription.model', settings.transcription.model),
      prefs.setString('summary.baseUrl', settings.summary.baseUrl),
      prefs.setString('summary.model', settings.summary.model),
      prefs.setString('appearance.theme', settings.themeMode.name),
      prefs.setBool('summary.imageMode', settings.imageMode),
      prefs.setBool('onboarding.completed', settings.onboardingCompleted),
    ]);
    if (realtimeApiKey != null) {
      await _writeSecret(_realtimeKey, realtimeApiKey);
    }
    if (transcriptionApiKey != null) {
      await _writeSecret(transcriptionSecretReference, transcriptionApiKey);
    }
    if (summaryApiKey != null) {
      await _writeSecret(summarySecretReference, summaryApiKey);
    }
  }

  @override
  Future<String> read(SecretReference reference) async {
    if (reference.id != _realtimeKey) {
      throw StateError('未知的安全存储引用。');
    }
    return await _secureStorage.read(key: _realtimeKey) ?? '';
  }

  Future<String> readServiceSecret(String reference) async {
    if (reference != transcriptionSecretReference &&
        reference != summarySecretReference) {
      throw StateError('未知的安全存储引用。');
    }
    return await _secureStorage.read(key: reference) ?? '';
  }

  Future<void> deleteServiceSecret(ServiceKind kind) async {
    final key = switch (kind) {
      ServiceKind.realtimeTranscription => _realtimeKey,
      ServiceKind.fileTranscription => transcriptionSecretReference,
      ServiceKind.summary => summarySecretReference,
    };
    await _secureStorage.delete(key: key);
  }

  Future<void> _writeSecret(String key, String value) async {
    if (value.isEmpty) {
      await _secureStorage.delete(key: key);
    } else {
      await _secureStorage.write(key: key, value: value);
    }
  }
}
