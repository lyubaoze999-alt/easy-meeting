import 'dart:async';
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
import 'package:easy_meeting/app_services/providers.dart';
import 'package:easy_meeting/app_services/recording_coordinator.dart';
import 'package:easy_meeting/app_services/recording_recovery_service.dart';
import 'package:easy_meeting/domain/models/platform_profile.dart';
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
import 'package:easy_meeting/ui/home_shell.dart';
import 'package:easy_meeting/ui/theme/theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Reusable builder for a real in-memory [AppServices] so the full business
/// [kHomeShellScreens] can render inside a widget test without a native plugin.
Future<AppServices> _buildTestAppServices(Directory root) async {
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
    capture: AudioCapture(platform: _StubAudioCapturePlatform()),
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
    recordingRecovery: recordingRecovery,
  );
}

class _StubAudioCapturePlatform extends AudioCapturePlatform {
  @override
  Stream<Map<String, Object?>> get events => const Stream.empty();
  @override
  Stream<AudioFrame> get pcmFrames => const Stream.empty();
  @override
  Future<Map<String, Object?>> start() async => const {'result': 'started'};
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<String> stop() async => '';
  @override
  Future<Map<String, Object?>> permissionStatus() async => const {
    'microphone': true,
    'systemAudio': true,
  };
  @override
  Future<void> openPermissionSettings({String? permission}) async {}
}

void main() {
  late AppServices services;
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('loop2-golden-');
    services = await _buildTestAppServices(root);
  });

  tearDown(() async {
    services.recording.dispose();
    await services.database.close();
    if (root.existsSync()) {
      await root.delete(recursive: true);
    }
  });

  for (final brightness in Brightness.values) {
    final mode = brightness == Brightness.dark ? 'dark' : 'light';
    for (final size in const [Size(880, 600), Size(1080, 720)]) {
      final extended = size.width >= 1080;
      final layout = extended ? 'extended' : 'compact';
      testWidgets('shell $mode $layout renders', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appServicesProvider.overrideWithValue(services),
              platformProfileProvider.overrideWithValue(
                const PlatformProfile(
                  platform: PlatformKind.macos,
                  form: DeviceForm.desktop,
                  audio: AudioCapability.dualSource,
                ),
              ),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: easyMeetingTheme(brightness),
              home: const HomeShell(),
            ),
          ),
        );
        // Let the shell focus autofocus and settle layout before capturing.
        // A fixed pump is used (not pumpAndSettle) because some business
        // screens drive a continuous animation that would never settle.
        await tester.pump(const Duration(milliseconds: 400));
        // Pixel-golden capture is a local evidence harness (env `EM_GEN_GOLDENS=1`).
        // The default CI `flutter test` (Ubuntu) renders CJK with different fonts
        // than this Windows host, so the default path is a deterministic smoke
        // assertion: the real shell renders at the contract size without overflow.
        if (Platform.environment['EM_GEN_GOLDENS'] == '1') {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile(
              'loop2/shell-$mode-$layout-${size.width}x${size.height}.png',
            ),
          );
        } else {
          expect(tester.takeException(), isNull);
          expect(find.byType(HomeShell), findsOneWidget);
        }
      });
    }
  }
}
