import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'audio_frame.dart';
import 'audio_capture_platform_interface.dart';

/// An implementation of [AudioCapturePlatform] that uses method channels.
class MethodChannelAudioCapture extends AudioCapturePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('audio_capture');
  final eventChannel = const EventChannel('audio_capture/events');
  final pcmEventChannel = const EventChannel('audio_capture/pcm');
  Stream<Map<String, Object?>>? _events;
  Stream<AudioFrame>? _pcmFrames;

  @override
  Stream<Map<String, Object?>> get events => _events ??= eventChannel
      .receiveBroadcastStream()
      .where((event) => event is Map)
      .map((event) => Map<String, Object?>.from(event as Map))
      .asBroadcastStream();

  @override
  Stream<AudioFrame> get pcmFrames => _pcmFrames ??= pcmEventChannel
      .receiveBroadcastStream()
      .where((event) => event is Map)
      .map((event) => AudioFrame.fromMap(event as Map<Object?, Object?>))
      .asBroadcastStream();

  @override
  Future<Map<String, Object?>> start() async => Map<String, Object?>.from(
    await methodChannel.invokeMapMethod<String, Object?>('start') ?? const {},
  );

  @override
  Future<void> pause() => methodChannel.invokeMethod<void>('pause');

  @override
  Future<void> resume() => methodChannel.invokeMethod<void>('resume');

  @override
  Future<String> stop() async =>
      await methodChannel.invokeMethod<String>('stop') ?? '';

  @override
  Future<Map<String, Object?>> permissionStatus() async =>
      Map<String, Object?>.from(
        await methodChannel.invokeMapMethod<String, Object?>(
              'permissionStatus',
            ) ??
            const {},
      );

  @override
  Future<void> openPermissionSettings({String? permission}) =>
      methodChannel.invokeMethod<void>('openPermissionSettings', permission);
}
