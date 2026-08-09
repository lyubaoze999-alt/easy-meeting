import 'dart:io';

import 'package:audio_capture/audio_capture.dart';
import 'package:audio_capture/audio_capture_platform_interface.dart';
import 'package:drift/native.dart';
import 'package:easy_meeting/app_services/app_services.dart';
import 'package:easy_meeting/app_services/managed_live_transcription_session.dart';
import 'package:easy_meeting/app_services/meeting_asset_lifecycle.dart';
import 'package:easy_meeting/app_services/meeting_session_controller.dart';
import 'package:easy_meeting/app_services/persistent_meeting_capture.dart';
import 'package:easy_meeting/app_services/post_processing_queue.dart';
import 'package:easy_meeting/app_services/processing_pipeline.dart';
import 'package:easy_meeting/app_services/recording_coordinator.dart';
import 'package:easy_meeting/app_services/recording_recovery_service.dart';
import 'package:easy_meeting/domain/summary/summary_service.dart';
import 'package:easy_meeting/domain/transcription/transcription_service.dart';
import 'package:easy_meeting/domain/transcription/wav_slicer.dart';
import 'package:easy_meeting/infrastructure/database/app_database.dart';
import 'package:easy_meeting/infrastructure/diagnostics/diagnostic_reporter.dart';
import 'package:easy_meeting/infrastructure/network/openai_compatible_client.dart';
import 'package:easy_meeting/infrastructure/notifications/completion_notifier.dart';
import 'package:easy_meeting/infrastructure/repositories/meeting_repository.dart';
import 'package:easy_meeting/infrastructure/repositories/note_repository.dart';
import 'package:easy_meeting/infrastructure/repositories/processing_job_repository.dart';
import 'package:easy_meeting/infrastructure/repositories/recording_repository.dart';
import 'package:easy_meeting/infrastructure/repositories/transcript_repository.dart';
import 'package:easy_meeting/infrastructure/settings/settings_store.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;

/// A no-op audio platform so recording-owned services can be constructed in a
/// widget test without a native plugin. `permissionStatus` is configurable via
/// [granted].
class StubAudioCapturePlatform extends AudioCapturePlatform {
  StubAudioCapturePlatform({this.granted = true});

  final bool granted;

  @override
  Stream<Map<String, Object?>> get events => const Stream.empty();
  @override
  Stream<AudioFrame> get pcmFrames => const Stream.empty();
  @override
  Future<Map<String, Object?>> start() async => const {
    'systemAudioAvailable': true,
    'microphoneAvailable': true,
    'nativeSessionId': 'test',
  };
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<String> stop() async => '';
  @override
  Future<Map<String, Object?>> permissionStatus() async => {
    'systemAudioGranted': granted,
    'microphoneGranted': granted,
  };
  @override
  Future<void> openPermissionSettings({String? permission}) async {}
}

/// Builds a real, in-memory [AppServices] bypassing path_provider and the
/// native audio plugin. Callers must dispose and close afterwards.
class TestAppServices {
  TestAppServices._(this.services, this.root);

  final AppServices services;
  final Directory root;

  static Future<TestAppServices> create() async {
    final root = await Directory.systemTemp.createTemp('easy-meeting-test-');
    final database = AppDatabase(NativeDatabase.memory());
    final notesDir = Directory(p.join(root.path, 'Notes'))
      ..createSync(recursive: true);
    final meetingsDir = Directory(p.join(root.path, 'Meetings'))
      ..createSync(recursive: true);
    final orphanDir = Directory(p.join(root.path, 'Orphans'))
      ..createSync(recursive: true);

    final notes = LocalNoteRepository(database, notesDir);
    final meetings = LocalMeetingRepository(database);
    final recordings = LocalRecordingRepository(
      database,
      meetingsDir,
      orphanDirectory: orphanDir,
    );
    final transcripts = LocalTranscriptRepository(database, meetingsDir);
    final jobs = LocalProcessingJobRepository(database);
    final settings = SettingsStore();
    final diagnostics = LocalDiagnosticReporter(
      File(p.join(root.path, 'events.jsonl')),
    );
    final notifications = LocalCompletionNotifier(
      FlutterLocalNotificationsPlugin(),
    );
    final client = OpenAICompatibleClient(
      apiKeyProvider: settings.readServiceSecret,
    );
    final recording = RecordingCoordinator(
      capture: AudioCapture(platform: StubAudioCapturePlatform()),
    );
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
    final transcriptionService = TranscriptionService(
      client: client,
      slicer: const WavSlicer(),
    );
    final summaryService = SummaryService(client);
    final processing = ProcessingPipeline(
      transcriptionService: transcriptionService,
      summaryService: summaryService,
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
      transcriptionService: transcriptionService,
      summaryService: summaryService,
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
    final recordingRecovery = RecordingRecoveryService(
      meetings: meetings,
      recordings: recordings,
      allowedDirectories: [recordings.baseDirectory, orphanDir],
      initialRecordings: const [],
    );
    final services = AppServices(
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
      recordingRecovery: recordingRecovery,
    );
    return TestAppServices._(services, root);
  }

  Future<void> dispose() async {
    services.recording.dispose();
    await services.database.close();
    if (root.existsSync()) {
      await root.delete(recursive: true);
    }
  }
}
