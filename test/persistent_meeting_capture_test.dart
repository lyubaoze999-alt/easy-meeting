import 'dart:io';

import 'package:audio_capture/audio_capture.dart';
import 'package:audio_capture/audio_capture_platform_interface.dart';
import 'package:drift/native.dart';
import 'package:easy_meeting/app_services/persistent_meeting_capture.dart';
import 'package:easy_meeting/app_services/recording_coordinator.dart';
import 'package:easy_meeting/domain/models/meeting_record.dart';
import 'package:easy_meeting/infrastructure/database/app_database.dart';
import 'package:easy_meeting/infrastructure/repositories/meeting_repository.dart';
import 'package:easy_meeting/infrastructure/repositories/recording_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_audio.dart';

void main() {
  test(
    'meeting becomes recorded only after WAV is archived and indexed',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final directory = await Directory.systemTemp.createTemp(
        'easy-meeting-persistent-capture-',
      );
      addTearDown(() async {
        await database.close();
        await directory.delete(recursive: true);
      });
      final nativeWav = await writePcmWav(
        directory,
        sampleRate: 24000,
        samples: 4800,
      );
      final coordinator = RecordingCoordinator(
        capture: AudioCapture(platform: _WavCapturePlatform(nativeWav.path)),
      );
      addTearDown(coordinator.dispose);
      final meetings = LocalMeetingRepository(database);
      final recordings = LocalRecordingRepository(
        database,
        Directory('${directory.path}/Meetings'),
      );
      final capture = PersistentMeetingCapture(
        coordinator: coordinator,
        meetings: meetings,
        recordings: recordings,
        idFactory: () => 'meeting-persistent',
      );

      await capture.start();
      expect(
        (await meetings.load('meeting-persistent'))?.status,
        MeetingStatus.recording,
      );

      await capture.stopAndSave();

      final meeting = await meetings.load('meeting-persistent');
      final asset = await recordings.loadForMeeting('meeting-persistent');
      expect(meeting?.status, MeetingStatus.recorded);
      expect(asset, isNotNull);
      expect(await File(asset!.path).exists(), isTrue);
      expect(asset.sha256, hasLength(64));
      expect(await nativeWav.exists(), isFalse);
    },
  );

  test(
    'finalization retries from an indexed asset without stopping twice',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final directory = await Directory.systemTemp.createTemp(
        'easy-meeting-persistent-retry-',
      );
      addTearDown(() async {
        await database.close();
        await directory.delete(recursive: true);
      });
      final nativeWav = await writePcmWav(
        directory,
        sampleRate: 24000,
        samples: 4800,
      );
      final platform = _WavCapturePlatform(nativeWav.path);
      final coordinator = RecordingCoordinator(
        capture: AudioCapture(platform: platform),
      );
      addTearDown(coordinator.dispose);
      final meetings = _FailOnceMeetingRepository(database);
      final recordings = LocalRecordingRepository(
        database,
        Directory('${directory.path}/Meetings'),
      );
      final capture = PersistentMeetingCapture(
        coordinator: coordinator,
        meetings: meetings,
        recordings: recordings,
        idFactory: () => 'meeting-retry',
      );

      await capture.start();
      await expectLater(capture.stopAndSave(), throwsStateError);
      expect(capture.hasPendingFinalization, isTrue);
      expect(platform.stopCalls, 1);
      expect(await recordings.loadForMeeting('meeting-retry'), isNotNull);
      expect(await nativeWav.exists(), isFalse);

      await capture.stopAndSave();
      expect(capture.hasPendingFinalization, isFalse);
      expect(platform.stopCalls, 1);
      expect(
        (await meetings.load('meeting-retry'))?.status,
        MeetingStatus.recorded,
      );
    },
  );
}

final class _FailOnceMeetingRepository extends LocalMeetingRepository {
  _FailOnceMeetingRepository(super.database);

  bool _failMetadata = true;

  @override
  Future<void> updateCaptureMetadata(
    String id, {
    required template,
    required highlights,
  }) async {
    if (_failMetadata) {
      _failMetadata = false;
      throw StateError('injected metadata failure');
    }
    await super.updateCaptureMetadata(
      id,
      template: template,
      highlights: highlights,
    );
  }
}

final class _WavCapturePlatform extends AudioCapturePlatform {
  _WavCapturePlatform(this.path);

  final String path;
  int stopCalls = 0;

  @override
  Stream<Map<String, Object?>> get events => const Stream.empty();

  @override
  Future<Map<String, Object?>> start() async => {
    'systemAudioAvailable': false,
    'microphoneAvailable': true,
    'nativeSessionId': 'native-session',
  };

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<String> stop() async {
    stopCalls += 1;
    return path;
  }

  @override
  Future<Map<String, Object?>> permissionStatus() async => const {};

  @override
  Future<void> openPermissionSettings({String? permission}) async {}
}
