import 'package:audio_capture/audio_capture.dart';
import 'package:audio_capture/audio_capture_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAudioCapturePlatform extends AudioCapturePlatform {
  String? requestedPermission;

  final controller = Stream<Map<String, Object?>>.fromIterable([
    {'type': 'systemLevel', 'value': 0.5},
  ]);

  @override
  Stream<Map<String, Object?>> get events => controller;

  @override
  Future<Map<String, Object?>> start() async => {
    'systemAudioAvailable': true,
    'microphoneAvailable': true,
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
    expect(await capture.systemLevel.first, 0.5);
    expect(await capture.stop(), '/tmp/meeting.wav');
  });

  test('forwards the requested permission to the native platform', () async {
    final platform = FakeAudioCapturePlatform();
    final capture = AudioCapture(platform: platform);

    await capture.openPermissionSettings(permission: 'systemAudio');

    expect(platform.requestedPermission, 'systemAudio');
  });
}
