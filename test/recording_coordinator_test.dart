import 'package:audio_capture/audio_capture.dart';
import 'package:audio_capture/audio_capture_platform_interface.dart';
import 'package:easy_meeting/app_services/recording_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'paused time is excluded and coordinator supports a second meeting',
    () async {
      final coordinator = RecordingCoordinator(
        capture: AudioCapture(platform: _FakeCapturePlatform()),
      );
      addTearDown(coordinator.dispose);

      final wallClock = Stopwatch()..start();
      await coordinator.start();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await coordinator.pause();
      final beforePause = coordinator.elapsed;
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final afterPause = coordinator.elapsed;
      expect((afterPause - beforePause).inMilliseconds.abs(), lessThan(30));

      await coordinator.resume();
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final first = await coordinator.stop();
      wallClock.stop();
      expect(first.duration.inMilliseconds, greaterThanOrEqualTo(180));
      expect(
        first.duration.inMilliseconds,
        lessThan(wallClock.elapsedMilliseconds - 60),
        reason:
            'the paused interval must not be written into the recording duration',
      );

      coordinator.reset();
      expect(coordinator.state, RecordingState.idle);
      await coordinator.start();
      final second = await coordinator.stop();
      expect(second.audioPath, endsWith('recording-2.wav'));
    },
  );
}

class _FakeCapturePlatform extends AudioCapturePlatform {
  int recordings = 0;

  @override
  Stream<Map<String, Object?>> get events => const Stream.empty();

  @override
  Future<Map<String, Object?>> start() async {
    recordings += 1;
    return {'systemAudioAvailable': true, 'microphoneAvailable': true};
  }

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<String> stop() async => '/tmp/recording-$recordings.wav';

  @override
  Future<Map<String, Object?>> permissionStatus() async => {
    'systemAudioGranted': true,
    'microphoneGranted': true,
  };

  @override
  Future<void> openPermissionSettings() async {}
}
