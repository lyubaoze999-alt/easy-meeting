import 'dart:typed_data';

import 'package:audio_capture/audio_capture.dart';
import 'package:audio_capture/audio_capture_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAudioCapturePlatform extends AudioCapturePlatform {
  String? requestedPermission;

  final controller = Stream<Map<String, Object?>>.fromIterable([
    {'type': 'systemLevel', 'value': 0.5},
  ]);

  final pcmController = Stream<AudioFrame>.fromIterable([
    AudioFrame(
      sessionId: 'native-session',
      sequence: 0,
      startSample: 0,
      sampleRate: AudioFrame.canonicalSampleRate,
      channels: AudioFrame.canonicalChannels,
      bytes: Uint8List(AudioFrame.canonicalBytesPerFrame),
    ),
  ]);

  @override
  Stream<Map<String, Object?>> get events => controller;

  @override
  Stream<AudioFrame> get pcmFrames => pcmController;

  @override
  Future<Map<String, Object?>> start() async => {
    'systemAudioAvailable': true,
    'microphoneAvailable': true,
    'nativeSessionId': 'native-session',
  };

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<String> stop() async => '/tmp/meeting.wav';

  @override
  Future<Map<String, Object?>> permissionStatus() async => {
    'systemAudioGranted': true,
    'microphoneGranted': true,
  };

  @override
  Future<void> openPermissionSettings({String? permission}) async {
    requestedPermission = permission;
  }
}

void main() {
  test('maps native start result and events', () async {
    final capture = AudioCapture(platform: FakeAudioCapturePlatform());
    final result = await capture.start();
    expect(result.systemAudioAvailable, isTrue);
    expect(result.nativeSessionId, 'native-session');
    expect(await capture.systemLevel.first, 0.5);
    expect((await capture.pcmFrames.first).bytes.lengthInBytes, 9600);
    expect(await capture.stop(), '/tmp/meeting.wav');
  });

  test('decodes binary PCM frames and detects continuity', () {
    final first = AudioFrame.fromMap({
      'sessionId': 'session-a',
      'sequence': 3,
      'startSample': 14400,
      'sampleRate': 24000,
      'channels': 1,
      'bytes': Uint8List(AudioFrame.canonicalBytesPerFrame),
    });
    final next = AudioFrame.fromMap({
      'sessionId': 'session-a',
      'sequence': 4,
      'startSample': 19200,
      'sampleRate': 24000,
      'channels': 1,
      'bytes': Uint8List(AudioFrame.canonicalBytesPerFrame),
    });

    expect(first.sampleCount, AudioFrame.canonicalSamplesPerFrame);
    expect(next.follows(first), isTrue);
  });

  test('rejects JSON-style PCM byte arrays', () {
    expect(
      () => AudioFrame.fromMap({
        'sessionId': 'session-a',
        'sequence': 0,
        'startSample': 0,
        'sampleRate': 24000,
        'channels': 1,
        'bytes': <int>[0, 0],
      }),
      throwsFormatException,
    );
  });

  test('forwards the requested permission to the native platform', () async {
    final platform = FakeAudioCapturePlatform();
    final capture = AudioCapture(platform: platform);

    await capture.openPermissionSettings(permission: 'systemAudio');

    expect(platform.requestedPermission, 'systemAudio');
  });
}
