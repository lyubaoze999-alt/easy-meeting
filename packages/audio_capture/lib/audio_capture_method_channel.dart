import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'audio_capture_platform_interface.dart';

/// An implementation of [AudioCapturePlatform] that uses method channels.
class MethodChannelAudioCapture extends AudioCapturePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('audio_capture');
  final eventChannel = const EventChannel('audio_capture/events');
  Stream<Map<String, Object?>>? _events;

  @override
  Stream<Map<String, Object?>> get events => _events ??= eventChannel
      .receiveBroadcastStream()
      .where((event) => event is Map)
      .map((event) => Map<String, Object?>.from(event as Map))
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
        await methodChannel.invokeMapMethod<String, Object?>('permissionStatus') ?? const {},
      );

  @override
  Future<void> openPermissionSettings() =>
      methodChannel.invokeMethod<void>('openPermissionSettings');
}
