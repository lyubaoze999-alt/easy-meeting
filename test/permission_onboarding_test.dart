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
import 'package:easy_meeting/ui/onboarding/permission_onboarding_screen.dart';
import 'package:easy_meeting/ui/theme/theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late AppServices services;
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('easy-meeting-onboarding-');
    services = await _buildTestAppServices(root);
  });

  tearDown(() async {
    services.recording.dispose();
    await services.database.close();
    if (root.existsSync()) {
      await root.delete(recursive: true);
    }
  });

  Future<void> pumpOnboarding({
    required WidgetTester tester,
    required PlatformProfile profile,
    required AudioPermissionStatus status,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appServicesProvider.overrideWithValue(services),
          platformProfileProvider.overrideWithValue(profile),
        ],
        child: MaterialApp(
          theme: easyMeetingTheme(Brightness.light),
          home: PermissionOnboardingScreen(
            capture: AudioCapture(platform: _StubPlatform(status)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows granted chip when both permissions are granted', (
    tester,
  ) async {
    await pumpOnboarding(
      tester: tester,
      profile: _macosProfile,
      status: const AudioPermissionStatus(
        systemAudioGranted: true,
        microphoneGranted: true,
      ),
    );
    expect(find.text('已授权'), findsNWidgets(2));
    expect(find.text('去授权'), findsNothing);
    expect(find.text('系统声音'), findsOneWidget);
    expect(find.text('麦克风'), findsOneWidget);
  });

  testWidgets('shows the grant button when permissions are not granted', (
    tester,
  ) async {
    await pumpOnboarding(
      tester: tester,
      profile: _macosProfile,
      status: const AudioPermissionStatus(
        systemAudioGranted: false,
        microphoneGranted: false,
      ),
    );
    expect(find.text('已授权'), findsNothing);
    expect(find.text('去授权'), findsNWidgets(2));
  });

  testWidgets('macOS 13-level mic-only capability shows the limitation card', (
    tester,
  ) async {
    await pumpOnboarding(
      tester: tester,
      profile: const PlatformProfile(
        platform: PlatformKind.macos,
        form: DeviceForm.desktop,
        audio: AudioCapability.micOnly,
      ),
      status: const AudioPermissionStatus(
        systemAudioGranted: true,
        microphoneGranted: true,
      ),
    );
    expect(find.text('当前平台仅支持麦克风录音'), findsOneWidget);
    expect(find.text('系统声音'), findsNothing);
  });

  testWidgets('refresh button re-reads permission state', (tester) async {
    // Start denied, then flip the stub to granted and tap refresh.
    final stub = _StubPlatform(
      const AudioPermissionStatus(
        systemAudioGranted: false,
        microphoneGranted: false,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appServicesProvider.overrideWithValue(services),
          platformProfileProvider.overrideWithValue(_macosProfile),
        ],
        child: MaterialApp(
          theme: easyMeetingTheme(Brightness.light),
          home: PermissionOnboardingScreen(
            capture: AudioCapture(platform: stub),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('去授权'), findsNWidgets(2));

    stub.status = const AudioPermissionStatus(
      systemAudioGranted: true,
      microphoneGranted: true,
    );
    await tester.tap(find.text('刷新权限状态'));
    await tester.pumpAndSettle();
    expect(find.text('已授权'), findsNWidgets(2));
  });
}

const _macosProfile = PlatformProfile(
  platform: PlatformKind.macos,
  form: DeviceForm.desktop,
  audio: AudioCapability.dualSource,
);

class _StubPlatform extends AudioCapturePlatform {
  _StubPlatform(this.status);

  AudioPermissionStatus status;

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
  Future<Map<String, Object?>> permissionStatus() async => {
    'systemAudioGranted': status.systemAudioGranted,
    'microphoneGranted': status.microphoneGranted,
  };
  @override
  Future<void> openPermissionSettings({String? permission}) async {}
}

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
    capture: AudioCapture(
      platform: _StubPlatform(
        const AudioPermissionStatus(
          systemAudioGranted: true,
          microphoneGranted: true,
        ),
      ),
    ),
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
