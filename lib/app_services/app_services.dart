import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/summary/summary_service.dart';
import '../domain/models/meeting_record.dart';
import '../domain/models/note_template.dart';
import '../domain/models/recording_asset.dart';
import '../domain/transcription/transcription_service.dart';
import '../domain/transcription/wav_slicer.dart';
import '../infrastructure/database/app_database.dart';
import '../infrastructure/diagnostics/diagnostic_reporter.dart';
import '../infrastructure/files/file_digest.dart';
import '../infrastructure/network/openai_compatible_client.dart';
import '../infrastructure/notifications/completion_notifier.dart';
import '../infrastructure/repositories/note_repository.dart';
import '../infrastructure/repositories/meeting_repository.dart';
import '../infrastructure/repositories/processing_job_repository.dart';
import '../infrastructure/repositories/recording_repository.dart';
import '../infrastructure/repositories/transcript_repository.dart';
import '../infrastructure/settings/settings_store.dart';
import 'meeting_session_controller.dart';
import 'managed_live_transcription_session.dart';
import 'meeting_asset_lifecycle.dart';
import 'processing_pipeline.dart';
import 'persistent_meeting_capture.dart';
import 'post_processing_queue.dart';
import 'recording_coordinator.dart';

class AppServices {
  AppServices({
    required this.database,
    required this.notes,
    required this.meetings,
    required this.recordings,
    required this.transcripts,
    required this.jobs,
    required this.settings,
    required this.diagnostics,
    required this.notifications,
    required this.recording,
    required this.persistentCapture,
    required this.liveTranscription,
    required this.postProcessing,
    required this.meetingAssets,
    required this.processing,
    required this.session,
    required this.orphanRecordings,
  });

  final AppDatabase database;
  final NoteRepository notes;
  final MeetingRepository meetings;
  final RecordingRepository recordings;
  final TranscriptRepository transcripts;
  final ProcessingJobRepository jobs;
  final SettingsStore settings;
  final DiagnosticReporter diagnostics;
  final CompletionNotifier notifications;
  final RecordingCoordinator recording;
  final PersistentMeetingCapture persistentCapture;
  final ManagedLiveTranscriptionSession liveTranscription;
  final PostProcessingQueue postProcessing;
  final MeetingAssetLifecycle meetingAssets;
  final ProcessingPipeline processing;
  final MeetingSessionController session;
  final List<OrphanRecording> orphanRecordings;
  Future<void>? _processingRecovery;

  bool get blocksExit => session.blocksExit;

  static Future<AppServices> create() async {
    final database = await AppDatabase.open();
    final notes = await LocalNoteRepository.open(database);
    final meetings = LocalMeetingRepository(database);
    final recordings = await LocalRecordingRepository.open(
      database,
      orphanDirectory: Directory(
        p.join(Directory.systemTemp.path, 'EasyMeetingRecordings'),
      ),
    );
    final transcripts = await LocalTranscriptRepository.open(database);
    final jobs = LocalProcessingJobRepository(database);
    final settings = SettingsStore();
    final diagnostics = await LocalDiagnosticReporter.open();
    final notifications = await LocalCompletionNotifier.open();
    final client = OpenAICompatibleClient(
      apiKeyProvider: settings.readServiceSecret,
    );
    final recording = RecordingCoordinator();
    final persistentCapture = PersistentMeetingCapture(
      coordinator: recording,
      meetings: meetings,
      recordings: recordings,
    );
    final liveTranscription = ManagedLiveTranscriptionSession(
      recording: recording,
      persistentCapture: persistentCapture,
      transcripts: transcripts,
      settings: settings,
    );
    final processing = ProcessingPipeline(
      transcriptionService: TranscriptionService(
        client: client,
        slicer: const WavSlicer(),
      ),
      summaryService: SummaryService(client),
      noteRepository: notes,
      jobRepository: jobs,
      diagnostics: diagnostics,
      notifier: notifications,
      settingsProvider: settings.load,
    );
    final postProcessing = PostProcessingQueue.fromServices(
      meetingRepository: meetings,
      recordingRepository: recordings,
      transcriptRepository: transcripts,
      noteRepository: notes,
      jobRepository: jobs,
      settingsProvider: settings.load,
      transcriptionService: TranscriptionService(
        client: client,
        slicer: const WavSlicer(),
      ),
      summaryService: SummaryService(client),
    );
    final meetingAssets = MeetingAssetLifecycle(
      meetings: meetings,
      notes: notes,
      meetingsDirectory: recordings.baseDirectory,
    );
    final session = MeetingSessionController(
      recording: recording,
      processing: processing,
      capturePort: persistentCapture,
      liveTranscript: liveTranscription,
      postProcessingQueue: postProcessing,
    );
    await notes.purgeExpired();
    await recordings.purgeExpired();
    await transcripts.purgeExpired();
    await meetingAssets.purgeExpired();
    final orphanRecordings = await _recoverFinalizedRecordings(
      meetings,
      recordings,
    );
    return AppServices(
      database: database,
      notes: notes,
      meetings: meetings,
      recordings: recordings,
      transcripts: transcripts,
      jobs: jobs,
      settings: settings,
      diagnostics: diagnostics,
      notifications: notifications,
      recording: recording,
      persistentCapture: persistentCapture,
      liveTranscription: liveTranscription,
      postProcessing: postProcessing,
      meetingAssets: meetingAssets,
      processing: processing,
      session: session,
      orphanRecordings: orphanRecordings,
    );
  }

  static Future<List<OrphanRecording>> _recoverFinalizedRecordings(
    MeetingRepository meetings,
    RecordingRepository recordings,
  ) async {
    final existingMeetings = await meetings.list();
    for (final meeting in existingMeetings) {
      if (meeting.status != MeetingStatus.recording) continue;
      final asset = await recordings.loadForMeeting(meeting.id);
      if (asset != null) await meetings.markRecorded(meeting.id, asset);
    }
    final unresolved = <OrphanRecording>[];
    for (final orphan in await recordings.scanOrphans()) {
      final stem = p.basenameWithoutExtension(orphan.path);
      final meetingId = 'recovered-$stem';
      try {
        if (await meetings.load(meetingId) == null) {
          await meetings.create(
            MeetingDraft(
              id: meetingId,
              startedAt: orphan.modifiedAt,
              templateSnapshot: NoteTemplate.builtins.first,
            ),
          );
        }
        final asset = await recordings.importNativeResult(
          meetingId,
          NativeRecordingResult(
            path: orphan.path,
            duration: Duration.zero,
            sourceProfile: AudioCaptureProfile.legacyUnknown,
            sha256: await calculateSha256(File(orphan.path)),
          ),
        );
        await meetings.markRecorded(meetingId, asset);
      } on Object {
        unresolved.add(orphan);
      }
    }
    // No native capture can still be active during cold start. Remove stale
    // draft rows that have no durable asset; recovered WAVs appear separately.
    for (final meeting in existingMeetings) {
      if (meeting.status == MeetingStatus.recording &&
          await recordings.loadForMeeting(meeting.id) == null) {
        await meetings.deleteDraft(meeting.id);
      }
    }
    return unresolved;
  }

  Future<void> resumeProcessing() =>
      _processingRecovery ??= _resumeProcessing();

  Future<void> _resumeProcessing() async {
    try {
      await session.initialize();
    } on Object {
      // The legacy controller persists and exposes its recoverable failure.
      // Startup recovery must still advance to the typed queue and must not
      // surface as an unhandled future from main().
    } finally {
      await postProcessing.resumePending();
    }
  }

  Future<void> close() async {
    await postProcessing.checkpointAndStop();
    final providerStillRunning = postProcessing.hasPendingWork;
    await liveTranscription.drain();
    session.dispose();
    liveTranscription.dispose();
    recording.dispose();
    processing.dispose();
    if (providerStillRunning) {
      unawaited(
        postProcessing.waitUntilIdle().then((_) async {
          postProcessing.dispose();
          await database.close();
        }),
      );
    } else {
      postProcessing.dispose();
      await database.close();
    }
  }
}
