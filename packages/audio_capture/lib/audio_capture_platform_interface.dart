import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'audio_frame.dart';
import 'audio_capture_method_channel.dart';

abstract class AudioCapturePlatform extends PlatformInterface {
  /// Constructs a AudioCapturePlatform.
  AudioCapturePlatform() : super(token: _token);

  static final Object _token = Object();

  static AudioCapturePlatform _instance = MethodChannelAudioCapture();

  /// The default instance of [AudioCapturePlatform] to use.
  ///
  /// Defaults to [MethodChannelAudioCapture].
  static AudioCapturePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AudioCapturePlatform] when
  /// they register themselves.
  static set instance(AudioCapturePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Stream<Map<String, Object?>> get events =>
      throw UnimplementedError('events has not been implemented.');

  Stream<AudioFrame> get pcmFrames =>
      throw UnimplementedError('pcmFrames has not been implemented.');

  Future<Map<String, Object?>> start() =>
      throw UnimplementedError('start has not been implemented.');

  Future<void> pause() =>
      throw UnimplementedError('pause has not been implemented.');

  Future<void> resume() =>
      throw UnimplementedError('resume has not been implemented.');

  Future<String> stop() =>
      throw UnimplementedError('stop has not been implemented.');

  Future<Map<String, Object?>> permissionStatus() =>
      throw UnimplementedError('permissionStatus has not been implemented.');

  Future<void> openPermissionSettings({String? permission}) =>
      throw UnimplementedError(
        'openPermissionSettings has not been implemented.',
      );
}
