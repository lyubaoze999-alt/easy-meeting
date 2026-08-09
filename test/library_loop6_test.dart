import 'dart:io';

import 'package:easy_meeting/app_services/providers.dart';
import 'package:easy_meeting/domain/models/asset_status.dart';
import 'package:easy_meeting/domain/models/meeting_note.dart';
import 'package:easy_meeting/domain/models/meeting_record.dart';
import 'package:easy_meeting/domain/models/note_template.dart';
import 'package:easy_meeting/domain/models/processing_job.dart';
import 'package:easy_meeting/domain/models/recording_asset.dart';
import 'package:easy_meeting/infrastructure/repositories/transcript_repository.dart';
import 'package:easy_meeting/ui/library/connected_meeting_library_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app_services.dart';
import 'test_audio.dart';

/// Loop 6: the meeting library must (R-10) search the formal transcript body
/// text and (R-04) project the real asset state — recording missing/damaged/
/// playable and summary notGenerated/processing/ready/failed — from the file
/// on disk and the Job queue, never from optimistic defaults. The search box
/// also debounces by 250ms so a keystroke does not immediately recompute every
/// bundle.
void main() {
  late TestAppServices harness;

  setUp(() async {
    harness = await TestAppServices.create();
  });

  tearDown(() async {
    await harness.dispose();
  });

  Future<MeetingRecord> seedMeeting(String id, DateTime startedAt) =>
      harness.services.meetings.create(
        MeetingDraft(
          id: id,
          startedAt: startedAt,
          templateSnapshot: NoteTemplate.builtins.first,
          highlights: const [],
        ),
      );

  Future<List<MeetingAssetBundle>?> loadFor(String query) async {
    final controller = MeetingLibraryController(harness.services);
    addTearDown(controller.dispose);
    await controller.load(query: query);
    return controller.state.value;
  }

  /// R-10 — a term that only appears in the formal transcript body must still
  /// surface its meeting.
  test('library search matches the formal transcript body text', () async {
    await seedMeeting('m-body', DateTime(2026, 8, 9, 14, 30));
    await seedMeeting('m-other', DateTime(2026, 8, 1, 9, 0));

    await (harness.services.transcripts as LocalTranscriptRepository)
        .saveBatchFinal(
          meetingId: 'm-body',
          body: '我们深入讨论了量子退火在组合优化中的应用。',
          revision: 1,
          coveredDuration: const Duration(seconds: 12),
        );

    final bundles = await loadFor('量子退火');
    expect(bundles, hasLength(1));
    expect(bundles!.single.meeting.id, 'm-body');

    // A query that matches nothing transcript-wise yields nothing.
    final none = await loadFor('不存在的关键词');
    expect(none, isEmpty);
  });

  /// R-04 — recording state comes from the real file.
  test(
    'recording status projects missing / damaged / playable from disk',
    () async {
      await seedMeeting('m-plain', DateTime(2026, 8, 1, 9, 0));
      await seedMeeting('m-damaged', DateTime(2026, 8, 2, 9, 0));
      await seedMeeting('m-playable', DateTime(2026, 8, 3, 9, 0));

      // m-damaged: asset row exists but the file is gone.
      final wav = await writePcmWav(
        harness.root,
        sampleRate: 16000,
        samples: 3200,
      );
      final damaged = await harness.services.recordings.importNativeResult(
        'm-damaged',
        NativeRecordingResult(
          path: wav.path,
          duration: const Duration(milliseconds: 200),
          sourceProfile: AudioCaptureProfile.microphoneOnly,
          sha256: 'ab' * 32,
        ),
      );
      await harness.services.meetings.markRecorded('m-damaged', damaged);
      await File(damaged.path).delete();

      // m-playable: real file present.
      final wav2 = await writePcmWav(
        harness.root,
        sampleRate: 16000,
        samples: 3200,
      );
      final playable = await harness.services.recordings.importNativeResult(
        'm-playable',
        NativeRecordingResult(
          path: wav2.path,
          duration: const Duration(milliseconds: 200),
          sourceProfile: AudioCaptureProfile.microphoneOnly,
          sha256: 'cd' * 32,
        ),
      );
      await harness.services.meetings.markRecorded('m-playable', playable);

      final bundles = await loadFor('');
      Map<String, MeetingAssetBundle> byId() => {
        for (final b in bundles!) b.meeting.id: b,
      };
      final map = byId();
      expect(map['m-plain']!.recordingStatus, RecordingDisplayStatus.missing);
      expect(map['m-damaged']!.recordingStatus, RecordingDisplayStatus.damaged);
      expect(
        map['m-playable']!.recordingStatus,
        RecordingDisplayStatus.playable,
      );
    },
  );

  /// R-04 — summary state comes from the Job queue, failed winning over a
  /// residual note, active meaning processing.
  test(
    'note status projects notGenerated / processing / failed / ready',
    () async {
      await seedMeeting('m-none', DateTime(2026, 8, 1, 9, 0));
      await seedMeeting('m-processing', DateTime(2026, 8, 2, 9, 0));
      await seedMeeting('m-failed', DateTime(2026, 8, 3, 9, 0));
      await seedMeeting('m-ready', DateTime(2026, 8, 4, 9, 0));
      await seedMeeting('m-scope', DateTime(2026, 8, 5, 9, 0));

      ProcessingJob job(String id, String meetingId, ProcessingStage stage) =>
          ProcessingJob(
            id: id,
            audioPath: 'unused.wav',
            template: NoteTemplate.builtins.first,
            startedAt: DateTime(2026, 8, 3),
            duration: const Duration(seconds: 5),
            highlights: const [],
            stage: stage,
            updatedAt: DateTime(2026, 8, 3),
            meetingId: meetingId,
            jobType: JobType.noteSummary,
            // A failed post-processing job is also reflected as a failed stage.
            checkpoint: stage == ProcessingStage.failed
                ? const {'postProcessingStage': 'failed'}
                : const {},
          );

      await harness.services.jobs.save(
        job('j-proc', 'm-processing', ProcessingStage.transcribing),
      );
      await harness.services.jobs.save(
        job('j-fail', 'm-failed', ProcessingStage.failed),
      );

      // m-ready even ships a residual damaged note + a failed job for a
      // different meeting to prove the projection is scoped per meeting.
      await harness.services.jobs.save(
        job('j-other', 'm-scope', ProcessingStage.failed),
      );
      final transcript =
          await (harness.services.transcripts as LocalTranscriptRepository)
              .saveBatchFinal(
                meetingId: 'm-ready',
                body: '会议正文',
                revision: 1,
                coveredDuration: const Duration(seconds: 5),
              );
      await harness.services.notes.save(
        MeetingNote(
          id: 'note-ready',
          title: '产品评审纪要',
          startedAt: DateTime(2026, 8, 4, 9, 0),
          duration: const Duration(seconds: 5),
          audioPath: 'a.wav',
          transcriptPath: transcript.bodyPath!,
          templateId: NoteTemplate.builtins.first.id,
          sections: const [NoteSection(heading: '结论', content: '通过')],
          todos: const [],
          highlights: const [],
          meetingId: 'm-ready',
          transcriptId: transcript.id,
        ),
      );

      final bundles = await loadFor('');
      final map = {for (final b in bundles!) b.meeting.id: b};
      expect(map['m-none']!.noteStatus, MeetingNoteDisplayStatus.notGenerated);
      expect(
        map['m-processing']!.noteStatus,
        MeetingNoteDisplayStatus.processing,
      );
      expect(map['m-failed']!.noteStatus, MeetingNoteDisplayStatus.failed);
      expect(map['m-ready']!.noteStatus, MeetingNoteDisplayStatus.ready);
    },
  );

  /// R-10 — the search box only recomputes after 250ms of quiet.
  testWidgets('library search box debounces for 250ms', (tester) async {
    await seedMeeting('m-alpha', DateTime(2026, 8, 9, 14, 30));
    await seedMeeting('m-beta', DateTime(2026, 8, 1, 9, 0));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appServicesProvider.overrideWithValue(harness.services)],
        child: const MaterialApp(
          home: Scaffold(
            body: SafeArea(child: ConnectedMeetingLibraryScreen()),
          ),
        ),
      ),
    );
    // Let the initial auto-load finish.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('8月9日 14:30 会议'), findsOneWidget);
    expect(find.text('8月1日 09:00 会议'), findsOneWidget);

    // Type a query that matches only m-beta. Before the debounce fires the
    // list must still show both.
    await tester.enterText(find.byType(TextField), 'beta');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('8月9日 14:30 会议'), findsOneWidget);
    expect(find.text('8月1日 09:00 会议'), findsOneWidget);

    // After 250ms the recompute runs and only m-beta remains.
    await tester.pump(const Duration(milliseconds: 250));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('8月9日 14:30 会议'), findsNothing);
    expect(find.text('8月1日 09:00 会议'), findsOneWidget);
  });
}
