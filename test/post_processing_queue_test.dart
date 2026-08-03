import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:audio_capture/audio_capture.dart';
import 'package:audio_capture/audio_capture_platform_interface.dart';
import 'package:easy_meeting/app_services/meeting_session_controller.dart';
import 'package:easy_meeting/app_services/meeting_session_state.dart';
import 'package:easy_meeting/app_services/post_processing_queue.dart';
import 'package:easy_meeting/app_services/processing_pipeline.dart';
import 'package:easy_meeting/app_services/recording_coordinator.dart';
import 'package:easy_meeting/domain/models/configuration.dart';
import 'package:easy_meeting/domain/models/meeting_note.dart';
import 'package:easy_meeting/domain/models/meeting_record.dart';
import 'package:easy_meeting/domain/models/note_template.dart';
import 'package:easy_meeting/domain/models/processing_job.dart';
import 'package:easy_meeting/domain/models/recording_asset.dart';
import 'package:easy_meeting/domain/models/transcript_document.dart';
import 'package:easy_meeting/domain/models/transcript_segment.dart';
import 'package:easy_meeting/domain/summary/summary_service.dart';
import 'package:easy_meeting/infrastructure/database/app_database.dart'
    hide ProcessingJob, RecordingAsset, TranscriptSegment;
import 'package:easy_meeting/infrastructure/repositories/meeting_repository.dart';
import 'package:easy_meeting/infrastructure/repositories/note_repository.dart';
import 'package:easy_meeting/infrastructure/repositories/processing_job_repository.dart';
import 'package:easy_meeting/infrastructure/repositories/recording_repository.dart';
import 'package:easy_meeting/infrastructure/repositories/transcript_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';

void main() {
  late Directory directory;
  late _Fixture fixture;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'easy-meeting-post-processing-',
    );
    fixture = await _Fixture.create(directory);
  });

  tearDown(() async {
    await directory.delete(recursive: true);
  });

  test('recording notifications cannot overwrite typed queue state', () async {
    final queue = fixture.queue();
    final recording = RecordingCoordinator(
      capture: AudioCapture(platform: _PassiveCapturePlatform()),
    );
    final legacy = _InactiveLegacyPipeline();
    final session = MeetingSessionController(
      recording: recording,
      processing: legacy,
      capturePort: _UnusedCapturePort(),
      postProcessingQueue: queue,
    );
    addTearDown(() {
      session.dispose();
      recording.dispose();
      legacy.dispose();
      queue.dispose();
    });
    await session.initialize();
    queue.currentJob = ProcessingJob(
      id: 'typed-active',
      audioPath: fixture.recordings.assets[fixture.meeting.id]!.path,
      template: fixture.meeting.templateSnapshot,
      startedAt: fixture.meeting.startedAt,
      duration: fixture.meeting.duration,
      highlights: const [],
      stage: ProcessingStage.transcribing,
      updatedAt: DateTime.utc(2026, 8, 3),
      meetingId: fixture.meeting.id,
      jobType: JobType.transcriptFull,
      checkpoint: const {'postProcessingStage': 'processing'},
    );
    queue.notifyListeners();
    expect(session.state.postProcessingPhase, PostProcessingPhase.transcribing);

    recording.reset();

    expect(session.state.postProcessingPhase, PostProcessingPhase.transcribing);
  });

  test(
    'file transcription completes without automatically summarizing',
    () async {
      var transcriptionCalls = 0;
      var summaryCalls = 0;
      final queue = fixture.queue(
        transcribe:
            ({
              required audio,
              required workingDirectory,
              required config,
              onProgress,
            }) async {
              transcriptionCalls += 1;
              onProgress?.call(1, 1);
              return '只有正式转写，不生成纪要。';
            },
        summarize:
            ({
              required transcript,
              required template,
              required highlights,
              required imageMode,
              required config,
              required context,
            }) async {
              summaryCalls += 1;
              return _note(context: context);
            },
      );

      final enqueued = await queue.enqueueTranscript(fixture.meeting.id);
      expect(enqueued.postProcessingStage, PostProcessingStage.queued);
      expect(
        enqueued.checkpointJson,
        isNot(contains('never-persist-this-key')),
      );

      await queue.resumePending();

      final completed = await fixture.jobs.load(enqueued.id);
      expect(completed?.postProcessingStage, PostProcessingStage.done);
      expect(transcriptionCalls, 1);
      expect(summaryCalls, 0);
      expect(fixture.transcripts.saveBatchFinalNextCalls, 1);
      expect(fixture.notes.saved, isEmpty);
      final finalTranscript = await fixture.transcripts.finalForMeeting(
        fixture.meeting.id,
      );
      expect(finalTranscript?.status, TranscriptStatus.ready);
      expect(
        await File(finalTranscript!.bodyPath!).readAsString(),
        '只有正式转写，不生成纪要。',
      );
    },
  );

  test('summary cannot be queued without a ready final transcript', () async {
    final draftBody = File('${directory.path}/draft.txt');
    await draftBody.writeAsString('尚未冻结');
    fixture.transcripts.documents['draft'] = _transcript(
      id: 'draft',
      meetingId: fixture.meeting.id,
      kind: TranscriptKind.realtimeDraft,
      status: TranscriptStatus.collecting,
      revision: 0,
      bodyPath: draftBody.path,
    );
    final queue = fixture.queue();

    await expectLater(
      queue.enqueueSummary(fixture.meeting.id, 'draft'),
      throwsStateError,
    );

    expect(fixture.jobs.values, isEmpty);
    expect(fixture.notes.saved, isEmpty);
  });

  test('exit checkpoints without waiting for a hung provider', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    final queue = fixture.queue(
      transcribe:
          ({
            required audio,
            required workingDirectory,
            required config,
            onProgress,
          }) async {
            started.complete();
            await release.future;
            return '迟到结果不得在退出后持久化';
          },
    );
    final job = await queue.enqueueTranscript(fixture.meeting.id);
    final running = queue.resumePending();
    await started.future;

    await queue.checkpointAndStop().timeout(const Duration(seconds: 1));
    final checkpoint = await fixture.jobs.load(job.id);
    expect(checkpoint?.postProcessingStage, PostProcessingStage.uploading);

    release.complete();
    await running;
    final afterProvider = await fixture.jobs.load(job.id);
    expect(afterProvider?.postProcessingStage, PostProcessingStage.uploading);
    expect(fixture.transcripts.documents, isEmpty);
  });

  test(
    'summary keeps the transcript id and revision captured at enqueue',
    () async {
      final revisionOne = await fixture.transcripts.addFinal(
        meetingId: fixture.meeting.id,
        id: 'final-r1',
        revision: 1,
        body: '第一版固定正文',
      );
      String? summarizedText;
      final queue = fixture.queue(
        summarize:
            ({
              required transcript,
              required template,
              required highlights,
              required imageMode,
              required config,
              required context,
            }) async {
              summarizedText = transcript;
              return _note(context: context);
            },
      );
      final job = await queue.enqueueSummary(
        fixture.meeting.id,
        revisionOne.id,
      );

      await fixture.transcripts.addFinal(
        meetingId: fixture.meeting.id,
        id: 'final-r2',
        revision: 2,
        body: '后来产生的第二版',
      );
      await queue.resumePending();

      expect(summarizedText, '第一版固定正文');
      expect(job.checkpoint['transcriptRevision'], 1);
      expect(fixture.notes.saved.single.transcriptId, revisionOne.id);
      expect(
        (await fixture.jobs.load(job.id))?.postProcessingStage,
        PostProcessingStage.done,
      );
    },
  );

  test(
    'retry reuses a completed summary stage after persistence fails',
    () async {
      final transcript = await fixture.transcripts.addFinal(
        meetingId: fixture.meeting.id,
        id: 'final-retry',
        revision: 1,
        body: '重试输入',
      );
      var summaryCalls = 0;
      fixture.notes.failNextSave = true;
      final queue = fixture.queue(
        summarize:
            ({
              required transcript,
              required template,
              required highlights,
              required imageMode,
              required config,
              required context,
            }) async {
              summaryCalls += 1;
              return _note(context: context);
            },
      );
      final job = await queue.enqueueSummary(fixture.meeting.id, transcript.id);

      await queue.resumePending();
      final failed = await fixture.jobs.load(job.id);
      expect(failed?.postProcessingStage, PostProcessingStage.failed);
      expect(failed?.lastSuccessfulStage, ProcessingStage.summarizing);
      expect(summaryCalls, 1);

      await queue.retry(job.id);
      await queue.resumePending();

      final completed = await fixture.jobs.load(job.id);
      expect(completed?.postProcessingStage, PostProcessingStage.done);
      expect(completed?.retryCount, 1);
      expect(summaryCalls, 1, reason: 'the durable note draft is reused');
      expect(fixture.notes.saved, hasLength(1));
    },
  );

  test(
    'a finalized recording exists independently of post-processing jobs',
    () async {
      final queue = fixture.queue();

      await queue.resumePending();

      expect(fixture.jobs.values, isEmpty);
      final recording = await fixture.recordings.loadForMeeting(
        fixture.meeting.id,
      );
      expect(recording, isNotNull);
      expect(await File(recording!.path).exists(), isTrue);
      expect(fixture.transcripts.documents, isEmpty);
      expect(fixture.notes.saved, isEmpty);
    },
  );

  test('queued cancellation is durable and is not resumed', () async {
    var calls = 0;
    final queue = fixture.queue(
      transcribe:
          ({
            required audio,
            required workingDirectory,
            required config,
            onProgress,
          }) async {
            calls += 1;
            return '不应执行';
          },
    );
    final job = await queue.enqueueTranscript(fixture.meeting.id);

    expect(await queue.cancelQueued(job.id), isTrue);
    await queue.resumePending();

    expect(calls, 0);
    expect(
      (await fixture.jobs.load(job.id))?.postProcessingStage,
      PostProcessingStage.cancelled,
    );
    expect(await fixture.jobs.recoverable(), isEmpty);
  });

  test(
    'same-type duplicates are rejected and different meetings run serially',
    () async {
      await fixture.addRecordedMeeting('meeting-2');
      var running = 0;
      var maximumRunning = 0;
      final queue = fixture.queue(
        transcribe:
            ({
              required audio,
              required workingDirectory,
              required config,
              onProgress,
            }) async {
              running += 1;
              if (running > maximumRunning) maximumRunning = running;
              await Future<void>.delayed(const Duration(milliseconds: 5));
              running -= 1;
              return '串行结果';
            },
      );
      await queue.enqueueTranscript(fixture.meeting.id);

      await expectLater(
        queue.enqueueTranscript(fixture.meeting.id),
        throwsStateError,
      );
      await queue.enqueueTranscript('meeting-2');
      await queue.resumePending();

      expect(maximumRunning, 1);
    },
  );

  test('local repository persists a batch final idempotently', () async {
    final database = AppDatabase(NativeDatabase.memory());
    try {
      final meetings = LocalMeetingRepository(database);
      await meetings.create(
        MeetingDraft(
          id: 'local-meeting',
          startedAt: DateTime.utc(2026, 8, 3),
          templateSnapshot: NoteTemplate.builtins.first,
        ),
      );
      final repository = LocalTranscriptRepository(
        database,
        Directory('${directory.path}/local-meetings'),
      );

      final first = await repository.saveBatchFinal(
        meetingId: 'local-meeting',
        body: '批量正式转写',
        revision: 1,
        coveredDuration: const Duration(minutes: 2),
        providerProtocol: 'test',
        model: 'test-model',
      );
      final repeated = await repository.saveBatchFinal(
        meetingId: 'local-meeting',
        body: '批量正式转写',
        revision: 1,
        coveredDuration: const Duration(minutes: 2),
        providerProtocol: 'test',
        model: 'test-model',
      );

      expect(repeated.id, first.id);
      expect(first.status, TranscriptStatus.ready);
      expect(await File(first.bodyPath!).readAsString(), '批量正式转写');

      final checkpointed = await repository.saveBatchFinalNext(
        meetingId: 'local-meeting',
        body: '崩溃后复用的转写',
        coveredDuration: const Duration(minutes: 2),
        idempotencyKey: 'job-stable-id',
      );
      final recovered = await repository.saveBatchFinalNext(
        meetingId: 'local-meeting',
        body: '崩溃后复用的转写',
        coveredDuration: const Duration(minutes: 2),
        idempotencyKey: 'job-stable-id',
      );
      expect(recovered.id, checkpointed.id);
      expect(recovered.revision, checkpointed.revision);
      expect(await File(recovered.bodyPath!).readAsString(), '崩溃后复用的转写');
    } finally {
      await database.close();
    }
  });
}

MeetingNote _note({required SummaryContext context}) => MeetingNote(
  id: context.noteId ?? 'note-1',
  title: '固定版本纪要',
  startedAt: context.startedAt,
  duration: context.duration,
  audioPath: context.audioPath,
  transcriptPath: context.transcriptPath,
  templateId: NoteTemplate.builtins.first.id,
  sections: const [],
  todos: const [],
  highlights: const [],
);

TranscriptDocument _transcript({
  required String id,
  required String meetingId,
  required TranscriptKind kind,
  required TranscriptStatus status,
  required int revision,
  String? bodyPath,
}) => TranscriptDocument(
  id: id,
  meetingId: meetingId,
  kind: kind,
  status: status,
  coveredDuration: const Duration(minutes: 5),
  revision: revision,
  bodyPath: bodyPath,
  frozenAt: status == TranscriptStatus.ready
      ? DateTime.utc(2026, 8, 3, 1)
      : null,
  createdAt: DateTime.utc(2026, 8, 3),
  updatedAt: DateTime.utc(2026, 8, 3),
);

class _Fixture {
  _Fixture({
    required this.directory,
    required this.meeting,
    required this.meetings,
    required this.recordings,
    required this.transcripts,
    required this.notes,
    required this.jobs,
  });

  final Directory directory;
  final MeetingRecord meeting;
  final _FakeMeetingRepository meetings;
  final _FakeRecordingRepository recordings;
  final _FakeTranscriptRepository transcripts;
  final _FakeNoteRepository notes;
  final _FakeProcessingJobRepository jobs;

  static Future<_Fixture> create(Directory directory) async {
    final audio = File('${directory.path}/recording.wav');
    await audio.writeAsBytes(const [1, 2, 3, 4]);
    final now = DateTime.utc(2026, 8, 3);
    final meeting = MeetingRecord(
      id: 'meeting-1',
      startedAt: now,
      endedAt: now.add(const Duration(minutes: 5)),
      duration: const Duration(minutes: 5),
      templateSnapshot: NoteTemplate.builtins.first,
      highlights: const [Duration(seconds: 30)],
      status: MeetingStatus.recorded,
      createdAt: now,
      updatedAt: now,
    );
    final recording = RecordingAsset(
      id: 'recording-1',
      meetingId: meeting.id,
      path: audio.path,
      mimeType: 'audio/wav',
      sampleRate: 24000,
      channels: 1,
      duration: meeting.duration,
      byteLength: await audio.length(),
      sha256: null,
      sourceProfile: AudioCaptureProfile.microphoneOnly,
      finalizedAt: now,
      createdAt: now,
      updatedAt: now,
    );
    return _Fixture(
      directory: directory,
      meeting: meeting,
      meetings: _FakeMeetingRepository(meeting),
      recordings: _FakeRecordingRepository(recording),
      transcripts: _FakeTranscriptRepository(directory),
      notes: _FakeNoteRepository(),
      jobs: _FakeProcessingJobRepository(),
    );
  }

  PostProcessingQueue queue({
    FileTranscriptionWorker? transcribe,
    NoteSummaryWorker? summarize,
  }) => PostProcessingQueue(
    meetingRepository: meetings,
    recordingRepository: recordings,
    transcriptRepository: transcripts,
    noteRepository: notes,
    jobRepository: jobs,
    settingsProvider: () async => const AppSettings(
      transcription: ServiceConfig(
        baseUrl: 'https://transcription.invalid/v1',
        apiKey: 'never-persist-this-key',
        model: 'transcription-model',
      ),
      summary: ServiceConfig(
        baseUrl: 'https://summary.invalid/v1',
        apiKey: 'never-persist-this-key',
        model: 'summary-model',
      ),
      imageMode: true,
    ),
    transcribe:
        transcribe ??
        ({
          required audio,
          required workingDirectory,
          required config,
          onProgress,
        }) async => '默认转写',
    summarize:
        summarize ??
        ({
          required transcript,
          required template,
          required highlights,
          required imageMode,
          required config,
          required context,
        }) async => _note(context: context),
    workingDirectory: Directory('${directory.path}/jobs'),
    autoStart: false,
    clock: () => DateTime.utc(2026, 8, 3, 2),
    idFactory: _nextId,
  );

  Future<void> addRecordedMeeting(String id) async {
    final audio = File('${directory.path}/$id.wav');
    await audio.writeAsBytes(const [1, 2, 3, 4]);
    final now = DateTime.utc(2026, 8, 3);
    final added = MeetingRecord(
      id: id,
      startedAt: now,
      endedAt: now.add(const Duration(minutes: 5)),
      duration: const Duration(minutes: 5),
      templateSnapshot: NoteTemplate.builtins.first,
      highlights: const [],
      status: MeetingStatus.recorded,
      createdAt: now,
      updatedAt: now,
    );
    meetings.records[id] = added;
    recordings.assets[id] = RecordingAsset(
      id: 'recording-$id',
      meetingId: id,
      path: audio.path,
      mimeType: 'audio/wav',
      sampleRate: 24000,
      channels: 1,
      duration: added.duration,
      byteLength: await audio.length(),
      sha256: null,
      sourceProfile: AudioCaptureProfile.microphoneOnly,
      finalizedAt: now,
      createdAt: now,
      updatedAt: now,
    );
  }
}

var _id = 0;
String _nextId() => 'job-${_id += 1}';

class _FakeProcessingJobRepository implements ProcessingJobRepository {
  final Map<String, ProcessingJob> values = {};

  @override
  Future<void> save(ProcessingJob job) async => values[job.id] = job;

  @override
  Future<ProcessingJob?> load(String id) async => values[id];

  @override
  Future<List<ProcessingJob>> recoverable() async =>
      values.values.where((job) => job.isRecoverable).toList(growable: false);

  @override
  Future<void> delete(String id) async => values.remove(id);
}

class _FakeMeetingRepository implements MeetingRepository {
  _FakeMeetingRepository(MeetingRecord record) : records = {record.id: record};
  final Map<String, MeetingRecord> records;

  @override
  Future<MeetingRecord?> load(String id) async => records[id];

  @override
  Future<List<MeetingRecord>> list({String query = ''}) async =>
      records.values.toList(growable: false);

  @override
  Future<List<MeetingRecord>> listTrash() async => const [];

  @override
  Future<MeetingRecord> create(MeetingDraft draft) =>
      throw UnimplementedError();

  @override
  Future<void> updateCaptureMetadata(
    String id, {
    required NoteTemplate template,
    required List<Duration> highlights,
  }) => throw UnimplementedError();

  @override
  Future<void> markRecorded(String id, RecordingAsset asset) =>
      throw UnimplementedError();

  @override
  Future<void> moveToTrash(String id) => throw UnimplementedError();

  @override
  Future<void> restore(String id) => throw UnimplementedError();

  @override
  Future<void> permanentlyDelete(String id) => throw UnimplementedError();

  @override
  Future<void> deleteDraft(String id) => throw UnimplementedError();
}

class _FakeRecordingRepository implements RecordingRepository {
  _FakeRecordingRepository(RecordingAsset asset)
    : assets = {asset.meetingId: asset};
  final Map<String, RecordingAsset> assets;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<RecordingAsset?> loadForMeeting(String meetingId) async =>
      assets[meetingId];

  @override
  Future<RecordingAsset> importNativeResult(
    String meetingId,
    NativeRecordingResult result,
  ) => throw UnimplementedError();

  @override
  Future<List<OrphanRecording>> scanOrphans() async => const [];

  @override
  Future<void> moveToTrash(String id) => throw UnimplementedError();
}

class _FakeTranscriptRepository
    implements
        TranscriptRepository,
        BatchFinalTranscriptRepository,
        RevisionAllocatingTranscriptRepository {
  _FakeTranscriptRepository(this.directory);
  final Directory directory;
  final Map<String, TranscriptDocument> documents = {};
  int saveBatchFinalNextCalls = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  Future<TranscriptDocument> addFinal({
    required String meetingId,
    required String id,
    required int revision,
    required String body,
  }) async {
    final file = File('${directory.path}/$id.txt');
    await file.writeAsString(body);
    final document = _transcript(
      id: id,
      meetingId: meetingId,
      kind: TranscriptKind.finalTranscript,
      status: TranscriptStatus.ready,
      revision: revision,
      bodyPath: file.path,
    );
    documents[id] = document;
    return document;
  }

  @override
  Future<TranscriptDocument> saveBatchFinal({
    required String meetingId,
    required String body,
    required int revision,
    required Duration coveredDuration,
    String? providerProtocol,
    String? model,
    String? language,
  }) async {
    final existing = documents.values.where(
      (item) =>
          item.meetingId == meetingId &&
          item.kind == TranscriptKind.finalTranscript &&
          item.revision == revision,
    );
    if (existing.isNotEmpty) return existing.first;
    return addFinal(
      meetingId: meetingId,
      id: 'batch-r$revision',
      revision: revision,
      body: body,
    );
  }

  @override
  Future<TranscriptDocument> saveBatchFinalNext({
    required String meetingId,
    required String body,
    required Duration coveredDuration,
    String? idempotencyKey,
    String? providerProtocol,
    String? model,
    String? language,
  }) async {
    saveBatchFinalNextCalls += 1;
    final latest = await finalForMeeting(meetingId);
    return saveBatchFinal(
      meetingId: meetingId,
      body: body,
      revision: (latest?.revision ?? 0) + 1,
      coveredDuration: coveredDuration,
      providerProtocol: providerProtocol,
      model: model,
      language: language,
    );
  }

  @override
  Future<TranscriptDocument> freezeNext(String draftId) =>
      throw UnimplementedError();

  @override
  Future<TranscriptDocument?> finalForMeeting(String meetingId) async {
    final finals =
        documents.values
            .where(
              (item) =>
                  item.meetingId == meetingId &&
                  item.kind == TranscriptKind.finalTranscript &&
                  item.status == TranscriptStatus.ready,
            )
            .toList()
          ..sort((left, right) => right.revision.compareTo(left.revision));
    return finals.isEmpty ? null : finals.first;
  }

  @override
  Future<TranscriptDocument?> load(String id) async => documents[id];

  @override
  Future<TranscriptDocument> createRealtimeDraft(String meetingId) =>
      throw UnimplementedError();

  @override
  Future<void> upsertDeltaSnapshot(TranscriptDeltaSnapshot snapshot) async {}

  @override
  Future<void> saveCompletedSegment(TranscriptSegment segment) async {}

  @override
  Future<TranscriptDocument> freeze(String draftId, {required int revision}) =>
      throw UnimplementedError();

  @override
  Future<void> markNeedsRepair(String id, List<TranscriptGap> gaps) async {}

  @override
  Future<List<TranscriptSegment>> segments(String transcriptId) async =>
      const [];
}

class _PassiveCapturePlatform extends AudioCapturePlatform {
  @override
  Stream<Map<String, Object?>> get events => const Stream.empty();

  @override
  Stream<AudioFrame> get pcmFrames => const Stream.empty();

  @override
  Future<Map<String, Object?>> start() async => const <String, Object?>{};

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<String> stop() async => '/tmp/unused.wav';

  @override
  Future<Map<String, Object?>> permissionStatus() async => const {};

  @override
  Future<void> openPermissionSettings({String? permission}) async {}
}

class _UnusedCapturePort implements MeetingCapturePort {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _InactiveLegacyPipeline extends ChangeNotifier
    implements ProcessingPipelinePort {
  @override
  ProcessingJob? get currentJob => null;

  @override
  ProcessingStage get stage => ProcessingStage.done;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeNoteRepository implements NoteRepository {
  final List<MeetingNote> saved = [];
  bool failNextSave = false;

  @override
  Future<MeetingNote> save(
    MeetingNote note, {
    File? audioSource,
    String? transcript,
  }) async {
    if (failNextSave) {
      failNextSave = false;
      throw StateError('simulated note persistence failure');
    }
    saved.add(note);
    return note;
  }

  @override
  Future<MeetingNote?> load(String id) async {
    for (final note in saved) {
      if (note.id == id) return note;
    }
    return null;
  }

  @override
  Future<List<MeetingNote>> list({String query = ''}) async =>
      List<MeetingNote>.of(saved);

  @override
  Future<List<MeetingNote>> listTrash() async => const [];

  @override
  Future<void> moveToTrash(String id) => throw UnimplementedError();

  @override
  Future<void> restore(String id) => throw UnimplementedError();

  @override
  Future<void> permanentlyDelete(String id) => throw UnimplementedError();

  @override
  Future<int> purgeExpired({DateTime? now}) async => 0;
}
