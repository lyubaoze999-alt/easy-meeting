export 'audio_frame.dart';

import 'audio_frame.dart';
import 'audio_capture_platform_interface.dart';

class AudioCaptureStartResult {
  const AudioCaptureStartResult({
    required this.systemAudioAvailable,
    required this.microphoneAvailable,
    required this.nativeSessionId,
    this.degradationReason,
  });

  final bool systemAudioAvailable;
  final bool microphoneAvailable;
  final String nativeSessionId;
  final String? degradationReason;

  factory AudioCaptureStartResult.fromMap(Map<String, Object?> map) =>
      AudioCaptureStartResult(
        systemAudioAvailable: map['systemAudioAvailable'] as bool? ?? false,
        microphoneAvailable: map['microphoneAvailable'] as bool? ?? false,
        nativeSessionId: map['nativeSessionId'] as String? ?? '',
        degradationReason: map['degradationReason'] as String?,
      );
}

class AudioPermissionStatus {
  const AudioPermissionStatus({
    required this.systemAudioGranted,
    required this.microphoneGranted,
  });

  final bool systemAudioGranted;
  final bool microphoneGranted;

  factory AudioPermissionStatus.fromMap(Map<String, Object?> map) =>
      AudioPermissionStatus(
        systemAudioGranted: map['systemAudioGranted'] as bool? ?? false,
        microphoneGranted: map['microphoneGranted'] as bool? ?? false,
      );
}

class AudioCapture {
  AudioCapture({AudioCapturePlatform? platform})
    : _platform = platform ?? AudioCapturePlatform.instance;

  final AudioCapturePlatform _platform;

  Stream<double> get systemLevel => _doubleEvents('systemLevel');
  Stream<double> get microphoneLevel => _doubleEvents('microphoneLevel');
  Stream<bool> get systemSilent => _boolEvents('systemSilent');
  Stream<bool> get microphoneSilent => _boolEvents('microphoneSilent');
  Stream<AudioFrame> get pcmFrames => _platform.pcmFrames;

  Future<AudioCaptureStartResult> start() async =>
      AudioCaptureStartResult.fromMap(await _platform.start());
  Future<void> pause() => _platform.pause();
  Future<void> resume() => _platform.resume();
  Future<String> stop() => _platform.stop();
  Future<AudioPermissionStatus> permissionStatus() async =>
      AudioPermissionStatus.fromMap(await _platform.permissionStatus());
  Future<void> openPermissionSettings({String? permission}) =>
      _platform.openPermissionSettings(permission: permission);

  Stream<double> _doubleEvents(String type) => _platform.events
      .where((event) => event['type'] == type)
      .map((event) => (event['value'] as num?)?.toDouble() ?? 0);

  Stream<bool> _boolEvents(String type) => _platform.events
      .where((event) => event['type'] == type)
      .map((event) => event['value'] as bool? ?? false);
}
