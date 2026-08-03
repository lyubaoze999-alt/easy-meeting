import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/configuration.dart';

class SettingsStore {
  SettingsStore({FlutterSecureStorage? secureStorage, this._preferences})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _transcriptionKey = 'service.transcription.apiKey';
  static const _summaryKey = 'service.summary.apiKey';
  final FlutterSecureStorage _secureStorage;
  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  Future<AppSettings> load() async {
    final prefs = await _prefs;
    return AppSettings(
      transcription: ServiceConfig(
        baseUrl: prefs.getString('transcription.baseUrl') ?? '',
        model: prefs.getString('transcription.model') ?? '',
        apiKey: await _secureStorage.read(key: _transcriptionKey) ?? '',
      ),
      summary: ServiceConfig(
        baseUrl: prefs.getString('summary.baseUrl') ?? '',
        model: prefs.getString('summary.model') ?? '',
        apiKey: await _secureStorage.read(key: _summaryKey) ?? '',
      ),
      themeMode: AppThemeMode.values.byName(
        prefs.getString('appearance.theme') ?? AppThemeMode.system.name,
      ),
      imageMode: prefs.getBool('summary.imageMode') ?? false,
      onboardingCompleted: prefs.getBool('onboarding.completed') ?? false,
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await _prefs;
    await Future.wait([
      prefs.setString('transcription.baseUrl', settings.transcription.baseUrl),
      prefs.setString('transcription.model', settings.transcription.model),
      prefs.setString('summary.baseUrl', settings.summary.baseUrl),
      prefs.setString('summary.model', settings.summary.model),
      prefs.setString('appearance.theme', settings.themeMode.name),
      prefs.setBool('summary.imageMode', settings.imageMode),
      prefs.setBool('onboarding.completed', settings.onboardingCompleted),
    ]);
    await _writeSecret(_transcriptionKey, settings.transcription.apiKey);
    await _writeSecret(_summaryKey, settings.summary.apiKey);
  }

  Future<void> _writeSecret(String key, String value) async {
    if (value.isEmpty) {
      await _secureStorage.delete(key: key);
    } else {
      await _secureStorage.write(key: key, value: value);
    }
  }
}
