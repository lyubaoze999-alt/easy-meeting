import 'dart:async';

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

  test('overlapping start commands cannot create two recordings', () async {
    final platform = _DelayedCapturePlatform();
    final coordinator = RecordingCoordinator(
      capture: AudioCapture(platform: platform),
    );
    addTearDown(coordinator.dispose);

    final firstStart = coordinator.start();
    expect(coordinator.operationInFlight, isTrue);
    await expectLater(coordinator.start(), throwsStateError);
    expect(platform.startCalls, 1);

    platform.startGate.complete({
      'systemAudioAvailable': true,
      'microphoneAvailable': true,
    });
    await firstStart;
    expect(coordinator.state, RecordingState.recording);
    expect(() => coordinator.reset(), throwsStateError);
  });

  test('a transition blocks every other recording command', () async {
    final platform = _DelayedCapturePlatform()..startGate.complete({});
    final coordinator = RecordingCoordinator(
      capture: AudioCapture(platform: platform),
    );
    addTearDown(coordinator.dispose);
    await coordinator.start();

    final pause = coordinator.pause();
    expect(coordinator.operationInFlight, isTrue);
    await expectLater(coordinator.stop(), throwsStateError);
    await expectLater(coordinator.resume(), throwsStateError);
    expect(platform.stopCalls, 0);

    platform.pauseGate.complete();
    await pause;
    expect(coordinator.state, RecordingState.paused);
  });

  test(
    'a native write-error is exposed and sticky until reset (R-05)',
    () async {
      final platform = _WriteErrorCapturePlatform();
      final coordinator = RecordingCoordinator(
        capture: AudioCapture(platform: platform),
      );
      addTearDown(coordinator.dispose);
      // The event stream is listened to lazily on first access; the
      // coordinator subscribes in its constructor, so give the broadcast a
      // turn to attach.
      await Future<void>.delayed(Duration.zero);
      expect(coordinator.writeErrorMessage, isNull);
      platform.emitWriteError('磁盘空间不足');
      await Future<void>.delayed(Duration.zero);
      expect(coordinator.writeErrorMessage, '磁盘空间不足');
      // Sticky: a second event keeps the first message's meaning; the capture
      // already stopped writing, so the UI must keep warning.
      platform.emitWriteError('设备已移除');
      await Future<void>.delayed(Duration.zero);
      expect(coordinator.writeErrorMessage, '设备已移除');
      // reset() clears it for the next meeting.
      coordinator.reset();
      expect(coordinator.writeErrorMessage, isNull);
    },
  );
}

class _WriteErrorCapturePlatform extends AudioCapturePlatform {
  final _controller = StreamController<Map<String, Object?>>.broadcast();

  @override
  Stream<Map<String, Object?>> get events => _controller.stream;

  void emitWriteError(String message) {
    _controller.add({'type': 'writeError', 'value': message});
  }

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
  Future<String> stop() async => '/tmp/r05.wav';

  @override
  Future<Map<String, Object?>> permissionStatus() async => {};

  @override
  Future<void> openPermissionSettings({String? permission}) async {}
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
  Future<void> openPermissionSettings({String? permission}) async {}
}

class _DelayedCapturePlatform extends AudioCapturePlatform {
  final Completer<Map<String, Object?>> startGate = Completer();
  final Completer<void> pauseGate = Completer();
  int startCalls = 0;
  int stopCalls = 0;

  @override
  Stream<Map<String, Object?>> get events => const Stream.empty();

  @override
  Future<Map<String, Object?>> start() {
    startCalls += 1;
    return startGate.future;
  }

  @override
  Future<void> pause() => pauseGate.future;

  @override
  Future<void> resume() async {}

  @override
  Future<String> stop() async {
    stopCalls += 1;
    return '/tmp/delayed-recording.wav';
  }

  @override
  Future<Map<String, Object?>> permissionStatus() async => {};

  @override
  Future<void> openPermissionSettings({String? permission}) async {}
}
