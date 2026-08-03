import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:easy_meeting/app_services/recording_recovery_service.dart';
import 'package:easy_meeting/domain/models/meeting_record.dart';
import 'package:easy_meeting/domain/models/recording_asset.dart';
import 'package:easy_meeting/infrastructure/database/app_database.dart';
import 'package:easy_meeting/infrastructure/repositories/meeting_repository.dart';
import 'package:easy_meeting/infrastructure/repositories/recording_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_audio.dart';

void main() {
  late AppDatabase database;
  late Directory root;
  late Directory orphanDirectory;
  late LocalMeetingRepository meetings;
  late LocalRecordingRepository recordings;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    root = await Directory.systemTemp.createTemp('meeting-recovery-test-');
    orphanDirectory = Directory('${root.path}/Orphans');
    await orphanDirectory.create(recursive: true);
    meetings = LocalMeetingRepository(database);
    recordings = LocalRecordingRepository(
      database,
      Directory('${root.path}/Meetings'),
      orphanDirectory: orphanDirectory,
    );
  });

  tearDown(() async {
    await database.close();
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('orphan recording is only archived after explicit action', () async {
    final source = await writePcmWav(orphanDirectory, samples: 1600);
    await _zeroWavLengths(source);
    final corruptedLength = await source.length();
    final corruptedHeader = await source
        .openRead(0, 44)
        .fold<List<int>>(<int>[], (bytes, chunk) => bytes..addAll(chunk));
    final headerData = ByteData.sublistView(
      Uint8List.fromList(corruptedHeader),
    );
    expect(headerData.getUint32(4, Endian.little), 0);
    expect(headerData.getUint32(40, Endian.little), 0);
    final orphan = (await recordings.scanOrphans()).single;
    final recovery = RecordingRecoveryService(
      meetings: meetings,
      recordings: recordings,
      allowedDirectories: [recordings.baseDirectory, orphanDirectory],
      initialRecordings: [orphan],
    );

    expect(await meetings.list(), isEmpty);
    expect(recovery.pending, hasLength(1));

    final asset = await recovery.archive(orphan);

    expect(recovery.pending, isEmpty);
    expect(await source.exists(), isFalse);
    expect(await File(asset.path).exists(), isTrue);
    expect(await File(asset.path).length(), corruptedLength);
    expect(asset.duration, const Duration(milliseconds: 100));
    expect(
      orphanDirectory.listSync().whereType<File>().where(
        (file) => file.path.endsWith('.recovery'),
      ),
      isEmpty,
    );
    expect(
      (await meetings.load(asset.meetingId))?.status,
      MeetingStatus.recorded,
    );
  });

  test('discard permanently removes a confirmed orphan', () async {
    final source = await writePcmWav(orphanDirectory);
    final orphan = (await recordings.scanOrphans()).single;
    final recovery = RecordingRecoveryService(
      meetings: meetings,
      recordings: recordings,
      allowedDirectories: [orphanDirectory],
      initialRecordings: [orphan],
    );

    final firstDiscard = recovery.discard(orphan);
    expect(recovery.isProcessing(orphan), isTrue);
    await expectLater(recovery.discard(orphan), throwsStateError);
    await firstDiscard;

    expect(await source.exists(), isFalse);
    expect(recovery.isProcessing(orphan), isFalse);
    expect(recovery.pending, isEmpty);
    expect(await meetings.list(), isEmpty);
  });

  test('discard refuses files outside the recovery roots', () async {
    final outside = await Directory.systemTemp.createTemp(
      'meeting-recovery-outside-',
    );
    addTearDown(() async {
      if (await outside.exists()) await outside.delete(recursive: true);
    });
    final source = await writePcmWav(outside);
    final orphan = OrphanRecording(
      path: source.path,
      byteLength: await source.length(),
      modifiedAt: DateTime.now(),
    );
    final recovery = RecordingRecoveryService(
      meetings: meetings,
      recordings: recordings,
      allowedDirectories: [orphanDirectory],
      initialRecordings: [orphan],
    );

    await expectLater(recovery.discard(orphan), throwsStateError);
    expect(await source.exists(), isTrue);
    expect(recovery.pending, hasLength(1));
  });

  test('failed header repair preserves the original recording', () async {
    final source = File('${orphanDirectory.path}/broken.wav');
    await source.writeAsBytes(List<int>.filled(80, 7), flush: true);
    final orphan = (await recordings.scanOrphans()).single;
    final recovery = RecordingRecoveryService(
      meetings: meetings,
      recordings: recordings,
      allowedDirectories: [orphanDirectory],
      initialRecordings: [orphan],
    );

    await expectLater(recovery.archive(orphan), throwsFormatException);

    expect(await source.exists(), isTrue);
    expect(await source.length(), 80);
    expect(recovery.pending, hasLength(1));
    expect(await meetings.list(), isEmpty);
  });
}

Future<void> _zeroWavLengths(File file) async {
  final original = Uint8List.fromList(await file.readAsBytes());
  final data = ByteData.sublistView(original);
  data.setUint32(4, 0, Endian.little);
  data.setUint32(40, 0, Endian.little);
  await file.writeAsBytes(original, flush: true);
}
