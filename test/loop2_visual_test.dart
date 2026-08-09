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

/// Deterministic light/dark visual evidence for the Loop 2 desktop shell at the
/// two contract viewport sizes (1080x720 extended, 880x600 compact). Renders
/// the real Calm Focus [HomeShell] with its real business screens so the rail,
/// page chrome, Chinese labels and Material icons are all production widgets.
void main() {
  late AppServices services;
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('easy-meeting-loop2-visual-');
    services = await _buildTestAppServices(root);
  });

  tearDown(() async {
    services.recording.dispose();
    await services.database.close();
    if (root.existsSync()) {
      await root.delete(recursive: true);
    }
  });

  const profile = PlatformProfile(
    platform: PlatformKind.macos,
    form: DeviceForm.desktop,
    audio: AudioCapability.dualSource,
  );

  Future<void> capture(
    WidgetTester tester, {
    required Size size,
    required Brightness brightness,
    required String name,
    int? selectLibrary,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appServicesProvider.overrideWithValue(services),
          platformProfileProvider.overrideWithValue(profile),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: easyMeetingTheme(Brightness.light),
          darkTheme: easyMeetingTheme(Brightness.dark),
          themeMode: brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          home: const HomeShell(),
        ),
      ),
    );
    // Let providers settle and the rail focus/layout stabilize.
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    if (selectLibrary == 1) {
      // "会议库" also appears as the library page's AppBar title and, in Compact
      // mode, the rail hides text labels entirely. The destination tooltip is
      // unique and present in both modes.
      await tester.tap(find.byTooltip('会议库（⌘2）'));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }
    // Pixel-golden comparison is a local evidence harness (env `EM_GEN_GOLDENS=1`).
    // The default CI `flutter test` (Ubuntu) renders CJK with different fonts than
    // this Windows host, so a committed byte-for-byte golden would be flaky there.
    // Instead, the default path is a deterministic smoke assertion: the real shell
    // renders at the contract size/brightness without any overflow exception.
    if (Platform.environment['EM_GEN_GOLDENS'] == '1') {
      await expectLater(
        find.byType(HomeShell),
        matchesGoldenFile('goldens/$name.png'),
      );
    } else {
      expect(tester.takeException(), isNull);
      expect(find.byType(HomeShell), findsOneWidget);
    }
  }

  testWidgets('desktop shell record page, light/dark, 1080x720 and 880x600', (
    tester,
  ) async {
    await capture(
      tester,
      size: const Size(1080, 720),
      brightness: Brightness.light,
      name: 'shell-record-light-1080x720',
    );
    await capture(
      tester,
      size: const Size(1080, 720),
      brightness: Brightness.dark,
      name: 'shell-record-dark-1080x720',
    );
    await capture(
      tester,
      size: const Size(880, 600),
      brightness: Brightness.light,
      name: 'shell-record-light-880x600',
    );
    await capture(
      tester,
      size: const Size(880, 600),
      brightness: Brightness.dark,
      name: 'shell-record-dark-880x600',
    );
  });

  testWidgets('desktop shell library page, light/dark, 1080x720 and 880x600', (
    tester,
  ) async {
    await capture(
      tester,
      size: const Size(1080, 720),
      brightness: Brightness.light,
      name: 'shell-library-light-1080x720',
      selectLibrary: 1,
    );
    await capture(
      tester,
      size: const Size(1080, 720),
      brightness: Brightness.dark,
      name: 'shell-library-dark-1080x720',
      selectLibrary: 1,
    );
    await capture(
      tester,
      size: const Size(880, 600),
      brightness: Brightness.light,
      name: 'shell-library-light-880x600',
      selectLibrary: 1,
    );
    await capture(
      tester,
      size: const Size(880, 600),
      brightness: Brightness.dark,
      name: 'shell-library-dark-880x600',
      selectLibrary: 1,
    );
  });
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

/// Builds a real, in-memory [AppServices] bypassing path_provider and the
/// native audio plugin (mirrors test/home_shell_test.dart).
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
