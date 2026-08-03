import 'dart:io';

import 'package:drift/native.dart';
import 'package:easy_meeting/domain/models/meeting_record.dart';
import 'package:easy_meeting/domain/models/meeting_note.dart';
import 'package:easy_meeting/domain/models/note_template.dart';
import 'package:easy_meeting/domain/models/recording_asset.dart';
import 'package:easy_meeting/domain/models/transcript_document.dart';
import 'package:easy_meeting/domain/models/transcript_segment.dart';
import 'package:easy_meeting/app_services/meeting_asset_lifecycle.dart';
import 'package:easy_meeting/infrastructure/database/app_database.dart'
    hide TranscriptSegment;
import 'package:easy_meeting/infrastructure/repositories/meeting_repository.dart';
import 'package:easy_meeting/infrastructure/repositories/note_repository.dart';
import 'package:easy_meeting/infrastructure/repositories/recording_repository.dart';
import 'package:easy_meeting/infrastructure/repositories/transcript_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_audio.dart';

void main() {
  late AppDatabase database;
  late Directory directory;
  late LocalMeetingRepository meetings;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    directory = await Directory.systemTemp.createTemp(
      'easy-meeting-assets-test-',
    );
    meetings = LocalMeetingRepository(database);
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('recording is persisted before a meeting becomes recorded', () async {
    await meetings.create(
      MeetingDraft(
        id: 'meeting-1',
        startedAt: DateTime.utc(2026, 8, 3),
        templateSnapshot: NoteTemplate.builtins.first,
        highlights: const [Duration(seconds: 3)],
      ),
    );
    final source = await writePcmWav(
      directory,
      sampleRate: 16000,
      samples: 3200,
    );
    final recordingRepository = LocalRecordingRepository(
      database,
      Directory('${directory.path}/Meetings'),
      digestCalculator: (_) async => 'ab' * 32,
    );

    final asset = await recordingRepository.importNativeResult(
      'meeting-1',
      NativeRecordingResult(
        path: source.path,
        duration: const Duration(milliseconds: 200),
        sourceProfile: AudioCaptureProfile.microphoneOnly,
      ),
    );
    expect(await source.exists(), isFalse);
    expect(await File(asset.path).exists(), isTrue);
    expect(asset.sampleRate, 16000);
    expect(asset.channels, 1);
    expect(asset.sha256, 'ab' * 32);

    await meetings.markRecorded('meeting-1', asset);
    final savedMeeting = await meetings.load('meeting-1');
    expect(savedMeeting?.status, MeetingStatus.recorded);
    expect(savedMeeting?.duration, const Duration(milliseconds: 200));
    expect(
      (await recordingRepository.loadForMeeting('meeting-1'))?.id,
      asset.id,
    );
  });

  test(
    'completed segments freeze in timeline order at a fixed revision',
    () async {
      await meetings.create(
        MeetingDraft(
          id: 'meeting-2',
          startedAt: DateTime.utc(2026, 8, 3),
          templateSnapshot: NoteTemplate.builtins.first,
        ),
      );
      final repository = LocalTranscriptRepository(
        database,
        Directory('${directory.path}/Meetings'),
      );
      final draft = await repository.createRealtimeDraft('meeting-2');
      final now = DateTime.utc(2026, 8, 3, 1);
      await repository.saveCompletedSegment(
        TranscriptSegment(
          id: 'segment-2',
          transcriptId: draft.id,
          providerItemId: 'item-2',
          ordinal: 2,
          start: const Duration(seconds: 1),
          end: const Duration(seconds: 2),
          text: '第二段',
          isFinal: true,
          source: TranscriptSegmentSource.realtime,
          updatedAt: now,
        ),
      );
      await repository.saveCompletedSegment(
        TranscriptSegment(
          id: 'segment-1',
          transcriptId: draft.id,
          providerItemId: 'item-1',
          ordinal: 1,
          start: Duration.zero,
          end: const Duration(seconds: 1),
          text: '第一段',
          isFinal: true,
          source: TranscriptSegmentSource.realtime,
          updatedAt: now,
        ),
      );
      await repository.upsertDeltaSnapshot(
        TranscriptDeltaSnapshot(
          transcriptId: draft.id,
          pendingTextByItem: const {'item-3': '草稿'},
          updatedAt: now,
        ),
      );

      final frozen = await repository.freeze(draft.id, revision: 1);
      expect(frozen.kind, TranscriptKind.finalTranscript);
      expect(frozen.status, TranscriptStatus.ready);
      expect(frozen.revision, 1);
      expect(frozen.coveredDuration, const Duration(seconds: 2));
      expect(await File(frozen.bodyPath!).readAsString(), '第一段\n第二段');
      expect(
        (await repository.segments(frozen.id)).map((segment) => segment.text),
        ['第一段', '第二段'],
      );
      expect((await repository.finalForMeeting('meeting-2'))?.id, frozen.id);
      expect(
        await File(
          '${directory.path}/Meetings/meeting-2/transcripts/realtime-draft.json',
        ).exists(),
        isTrue,
      );
    },
  );

  test(
    'concurrent realtime and batch final allocation keeps unique bodies',
    () async {
      await meetings.create(
        MeetingDraft(
          id: 'meeting-concurrent-final',
          startedAt: DateTime.utc(2026, 8, 3),
          templateSnapshot: NoteTemplate.builtins.first,
        ),
      );
      final repository = LocalTranscriptRepository(
        database,
        Directory('${directory.path}/Meetings'),
      );
      final draft = await repository.createRealtimeDraft(
        'meeting-concurrent-final',
      );
      await repository.saveCompletedSegment(
        TranscriptSegment(
          id: 'concurrent-realtime-segment',
          transcriptId: draft.id,
          providerItemId: 'concurrent-realtime-item',
          ordinal: 0,
          start: Duration.zero,
          end: const Duration(seconds: 2),
          text: '实时冻结正文',
          isFinal: true,
          source: TranscriptSegmentSource.realtime,
          updatedAt: DateTime.utc(2026, 8, 3, 1),
        ),
      );

      final results = await Future.wait([
        repository.freezeNext(draft.id),
        repository.saveBatchFinalNext(
          meetingId: 'meeting-concurrent-final',
          body: '文件转写正文',
          coveredDuration: const Duration(seconds: 2),
          providerProtocol: 'test-batch',
          model: 'test-model',
        ),
      ]);
      final realtime = results[0];
      final batch = results[1];
      final rows =
          await (database.select(database.transcripts)
                ..where(
                  (row) => row.meetingId.equals('meeting-concurrent-final'),
                )
                ..where(
                  (row) => row.kind.equals(TranscriptKind.finalTranscript.name),
                ))
              .get();

      expect(rows, hasLength(2));
      expect(rows.map((row) => row.revision).toSet(), {1, 2});
      expect({realtime.revision, batch.revision}, {1, 2});
      expect(realtime.bodyPath, isNot(batch.bodyPath));
      expect(await File(realtime.bodyPath!).readAsString(), '实时冻结正文');
      expect(await File(batch.bodyPath!).readAsString(), '文件转写正文');
    },
  );

  test('a draft with a known gap cannot be frozen', () async {
    await meetings.create(
      MeetingDraft(
        id: 'meeting-3',
        startedAt: DateTime.utc(2026, 8, 3),
        templateSnapshot: NoteTemplate.builtins.first,
      ),
    );
    final repository = LocalTranscriptRepository(
      database,
      Directory('${directory.path}/Meetings'),
    );
    final draft = await repository.createRealtimeDraft('meeting-3');
    await repository.markNeedsRepair(draft.id, const [
      TranscriptGap(
        start: Duration(seconds: 2),
        end: Duration(seconds: 5),
        reason: 'network_disconnect',
      ),
    ]);

    await expectLater(
      repository.freeze(draft.id, revision: 1),
      throwsStateError,
    );
    expect(
      (await repository.load(draft.id))?.gaps.single.reason,
      'network_disconnect',
    );
  });

  test('recording and transcript have independent trash lifecycles', () async {
    await meetings.create(
      MeetingDraft(
        id: 'meeting-independent-trash',
        startedAt: DateTime.utc(2026, 8, 3),
        templateSnapshot: NoteTemplate.builtins.first,
      ),
    );
    final source = await writePcmWav(
      directory,
      sampleRate: 16000,
      samples: 1600,
    );
    final recordingRepository = LocalRecordingRepository(
      database,
      Directory('${directory.path}/Meetings'),
      digestCalculator: (_) async => 'cd' * 32,
    );
    final recording = await recordingRepository.importNativeResult(
      'meeting-independent-trash',
      NativeRecordingResult(
        path: source.path,
        duration: const Duration(milliseconds: 100),
        sourceProfile: AudioCaptureProfile.microphoneOnly,
      ),
    );
    await meetings.markRecorded('meeting-independent-trash', recording);
    final transcriptRepository = LocalTranscriptRepository(
      database,
      Directory('${directory.path}/Meetings'),
    );
    final transcript = await transcriptRepository.saveBatchFinalNext(
      meetingId: 'meeting-independent-trash',
      body: '独立转写保留',
      coveredDuration: recording.duration,
      idempotencyKey: 'independent-trash-job',
    );

    await recordingRepository.moveToTrash(recording.id);
    expect(
      await recordingRepository.loadForMeeting('meeting-independent-trash'),
      isNull,
    );
    expect(
      (await transcriptRepository.finalForMeeting(
        'meeting-independent-trash',
      ))?.id,
      transcript.id,
    );
    await recordingRepository.restore(recording.id);
    expect(
      await recordingRepository.loadForMeeting('meeting-independent-trash'),
      isNotNull,
    );

    await transcriptRepository.moveToTrash(transcript.id);
    expect(
      await transcriptRepository.finalForMeeting('meeting-independent-trash'),
      isNull,
    );
    expect(
      await recordingRepository.loadForMeeting('meeting-independent-trash'),
      isNotNull,
    );
    await transcriptRepository.restore(transcript.id);
    await transcriptRepository.moveToTrash(transcript.id);
    await transcriptRepository.permanentlyDelete(transcript.id);
    expect(await File(transcript.bodyPath!).exists(), isFalse);
  });

  test(
    'a linked note keeps independent recording and transcript ownership',
    () async {
      await meetings.create(
        MeetingDraft(
          id: 'meeting-linked',
          startedAt: DateTime.utc(2026, 8, 3),
          templateSnapshot: NoteTemplate.builtins.first,
        ),
      );
      final transcriptRepository = LocalTranscriptRepository(
        database,
        Directory('${directory.path}/Meetings'),
      );
      final draft = await transcriptRepository.createRealtimeDraft(
        'meeting-linked',
      );
      await transcriptRepository.saveCompletedSegment(
        TranscriptSegment(
          id: 'segment-linked',
          transcriptId: draft.id,
          providerItemId: 'item-linked',
          ordinal: 0,
          start: Duration.zero,
          end: const Duration(minutes: 1),
          text: '保持只读',
          isFinal: true,
          source: TranscriptSegmentSource.realtime,
          updatedAt: DateTime.utc(2026, 8, 3),
        ),
      );
      final transcript = await transcriptRepository.freeze(
        draft.id,
        revision: 1,
      );
      final noteRepository = LocalNoteRepository(
        database,
        Directory('${directory.path}/Notes'),
      );
      final note = MeetingNote(
        id: 'note-linked',
        meetingId: 'meeting-linked',
        transcriptId: transcript.id,
        title: '独立资产会议',
        startedAt: DateTime.utc(2026, 8, 3),
        duration: const Duration(minutes: 1),
        audioPath: '${directory.path}/Meetings/meeting-linked/audio.wav',
        transcriptPath: transcript.bodyPath!,
        templateId: 'builtin.default',
        sections: const [NoteSection(heading: '结论', content: '保持只读')],
        todos: const [],
        highlights: const [],
      );

      final saved = await noteRepository.save(note);

      expect(saved.audioPath, note.audioPath);
      expect(saved.transcriptPath, note.transcriptPath);
      expect(
        await File('${directory.path}/Notes/note-linked/audio.wav').exists(),
        isFalse,
      );
      expect(
        await File(
          '${directory.path}/Notes/note-linked/transcript.txt',
        ).exists(),
        isFalse,
      );
    },
  );

  test(
    'meeting trash restores and permanently removes its asset directory',
    () async {
      await meetings.create(
        MeetingDraft(
          id: 'meeting-trash',
          startedAt: DateTime.utc(2026, 8, 3),
          templateSnapshot: NoteTemplate.builtins.first,
        ),
      );
      await database.customStatement(
        "UPDATE meetings SET status = 'recorded' WHERE id = ?",
        const ['meeting-trash'],
      );
      final meetingsDirectory = Directory('${directory.path}/Meetings');
      final assetDirectory = Directory(
        '${meetingsDirectory.path}/meeting-trash/recording',
      );
      await assetDirectory.create(recursive: true);
      await File('${assetDirectory.path}/sentinel').writeAsString('asset');
      final lifecycle = MeetingAssetLifecycle(
        meetings: meetings,
        notes: LocalNoteRepository(
          database,
          Directory('${directory.path}/Notes'),
        ),
        meetingsDirectory: meetingsDirectory,
      );

      await meetings.moveToTrash('meeting-trash');
      expect((await lifecycle.listTrash()).single.meeting.id, 'meeting-trash');
      await lifecycle.restore('meeting-trash');
      expect((await meetings.load('meeting-trash'))?.deletedAt, isNull);

      await meetings.moveToTrash('meeting-trash');
      await lifecycle.permanentlyDelete('meeting-trash');
      expect(await meetings.load('meeting-trash'), isNull);
      expect(
        await Directory('${meetingsDirectory.path}/meeting-trash').exists(),
        isFalse,
      );
    },
  );
}
