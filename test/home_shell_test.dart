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
import 'package:easy_meeting/ui/shell/desktop_navigation.dart';
import 'package:easy_meeting/ui/theme/theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late AppServices services;
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('easy-meeting-home-shell-');
    services = await _buildTestAppServices(root);
  });

  tearDown(() async {
    services.recording.dispose();
    await services.database.close();
    if (root.existsSync()) {
      await root.delete(recursive: true);
    }
  });

  group('desktop breakpoints and rail width', () {
    testWidgets('880x600 renders the Compact rail at width 72', (tester) async {
      await _setSurface(tester, const Size(880, 600));
      final controller = _CountingLibraryController(services);
      await _pumpShell(
        tester,
        services: services,
        profile: _macosProfile,
        libraryController: controller,
      );
      expect(find.byType(DesktopNavigation), findsOneWidget);
      expect(
        tester.getSize(find.byType(DesktopNavigation)).width,
        kShellCompactRailWidth,
      );
      expect(find.text('记录'), findsNothing);
    });

    testWidgets('1080x720 renders the Extended rail at width 224 with labels', (
      tester,
    ) async {
      await _setSurface(tester, const Size(1080, 720));
      final controller = _CountingLibraryController(services);
      await _pumpShell(
        tester,
        services: services,
        profile: _macosProfile,
        libraryController: controller,
      );
      expect(
        tester.getSize(find.byType(DesktopNavigation)).width,
        kShellExtendedRailWidth,
      );
      expect(find.text('会议库'), findsOneWidget);
      expect(find.text('回收站'), findsOneWidget);
    });
  });

  group('destination selection', () {
    testWidgets('clicking each destination shows the right page', (
      tester,
    ) async {
      await _setSurface(tester, const Size(1080, 720));
      final controller = _CountingLibraryController(services);
      await _pumpShell(
        tester,
        services: services,
        profile: _macosProfile,
        libraryController: controller,
      );
      expect(_visible(tester, 'record-page'), findsOneWidget);
      await tester.tap(find.text('会议库'));
      await tester.pumpAndSettle();
      expect(_visible(tester, 'library-page'), findsOneWidget);
      await tester.tap(find.text('回收站'));
      await tester.pumpAndSettle();
      expect(_visible(tester, 'trash-page'), findsOneWidget);
      await tester.tap(find.text('设置'));
      await tester.pumpAndSettle();
      expect(_visible(tester, 'settings-page'), findsOneWidget);
    });

    testWidgets('re-selecting the current page does not reload the library', (
      tester,
    ) async {
      await _setSurface(tester, const Size(1080, 720));
      final controller = _CountingLibraryController(services);
      await _pumpShell(
        tester,
        services: services,
        profile: _macosProfile,
        libraryController: controller,
      );
      // Switching into the library loads it once.
      await tester.tap(find.text('会议库'));
      await tester.pumpAndSettle();
      expect(controller.loadCount, 1);
      // Re-selecting the already-visible library must be a no-op.
      await tester.tap(find.text('会议库'));
      await tester.pumpAndSettle();
      expect(controller.loadCount, 1);
      // Leaving and coming back loads it again.
      await tester.tap(find.text('记录'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('会议库'));
      await tester.pumpAndSettle();
      expect(controller.loadCount, 2);
    });

    testWidgets('IndexedStack preserves page-local state across navigation', (
      tester,
    ) async {
      await _setSurface(tester, const Size(1080, 720));
      final controller = _CountingLibraryController(services);
      await _pumpShell(
        tester,
        services: services,
        profile: _macosProfile,
        libraryController: controller,
        recordPage: const _CounterPage(),
      );
      expect(_visible(tester, 'count-0'), findsOneWidget);
      await tester.tap(find.text('increment'));
      await tester.pumpAndSettle();
      expect(_visible(tester, 'count-1'), findsOneWidget);
      // Navigate away and back; the counter must still read 1.
      await tester.tap(find.text('会议库'));
      await tester.pumpAndSettle();
      expect(_visible(tester, 'library-page'), findsOneWidget);
      await tester.tap(find.text('记录'));
      await tester.pumpAndSettle();
      expect(_visible(tester, 'count-1'), findsOneWidget);
    });
  });

  group('keyboard shortcuts', () {
    testWidgets('Cmd+digit switches pages on the macOS profile', (
      tester,
    ) async {
      await _setSurface(tester, const Size(1080, 720));
      final controller = _CountingLibraryController(services);
      await _pumpShell(
        tester,
        services: services,
        profile: _macosProfile,
        libraryController: controller,
      );
      await _pressWithModifier(tester, LogicalKeyboardKey.metaLeft, [
        LogicalKeyboardKey.digit2,
      ]);
      await tester.pumpAndSettle();
      expect(_visible(tester, 'library-page'), findsOneWidget);
      await _pressWithModifier(tester, LogicalKeyboardKey.metaLeft, [
        LogicalKeyboardKey.digit4,
      ]);
      await tester.pumpAndSettle();
      expect(_visible(tester, 'settings-page'), findsOneWidget);
    });

    testWidgets('Ctrl+digit switches pages on the Windows profile', (
      tester,
    ) async {
      await _setSurface(tester, const Size(1080, 720));
      final controller = _CountingLibraryController(services);
      await _pumpShell(
        tester,
        services: services,
        profile: _windowsProfile,
        libraryController: controller,
      );
      await _pressWithModifier(tester, LogicalKeyboardKey.controlLeft, [
        LogicalKeyboardKey.digit3,
      ]);
      await tester.pumpAndSettle();
      expect(_visible(tester, 'trash-page'), findsOneWidget);
    });

    testWidgets('plain digit input into a TextField does not switch pages', (
      tester,
    ) async {
      await _setSurface(tester, const Size(1080, 720));
      final controller = _CountingLibraryController(services);
      final fieldController = TextEditingController();
      final fieldFocus = FocusNode(debugLabel: 'test-field');
      addTearDown(fieldController.dispose);
      addTearDown(fieldFocus.dispose);
      await _pumpShell(
        tester,
        services: services,
        profile: _macosProfile,
        libraryController: controller,
        recordPage: _TextFieldPage(fieldController, fieldFocus),
      );
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(fieldFocus.hasFocus, isTrue);
      // A plain digit (no modifier) must not be swallowed by the shell's
      // destination shortcuts: the page stays put and the field keeps focus.
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2, character: '2');
      await tester.pumpAndSettle();
      expect(fieldFocus.hasFocus, isTrue);
      expect(_visible(tester, 'record-page'), findsOneWidget);
      // ...but the modifier shortcut still switches.
      await _pressWithModifier(tester, LogicalKeyboardKey.metaLeft, [
        LogicalKeyboardKey.digit2,
      ]);
      await tester.pumpAndSettle();
      expect(_visible(tester, 'library-page'), findsOneWidget);
    });

    testWidgets('a shortcut moves focus onto the visible rail', (tester) async {
      await _setSurface(tester, const Size(1080, 720));
      final controller = _CountingLibraryController(services);
      final fieldController = TextEditingController();
      final fieldFocus = FocusNode(debugLabel: 'test-field');
      addTearDown(fieldController.dispose);
      addTearDown(fieldFocus.dispose);
      await _pumpShell(
        tester,
        services: services,
        profile: _macosProfile,
        libraryController: controller,
        recordPage: _TextFieldPage(fieldController, fieldFocus),
      );
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(fieldFocus.hasFocus, isTrue);
      await _pressWithModifier(tester, LogicalKeyboardKey.metaLeft, [
        LogicalKeyboardKey.digit2,
      ]);
      await tester.pumpAndSettle();
      // Focus left the text field and is no longer stranded on the hidden page.
      expect(fieldFocus.hasFocus, isFalse);
    });
  });

  group('mobile regression', () {
    testWidgets(
      'mobile profile keeps the bottom NavigationBar and four entries',
      (tester) async {
        await _setSurface(tester, const Size(400, 800));
        final controller = _CountingLibraryController(services);
        await _pumpShell(
          tester,
          services: services,
          profile: _mobileProfile,
          libraryController: controller,
        );
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byType(DesktopNavigation), findsNothing);
        expect(find.text('记录'), findsOneWidget);
        expect(find.text('会议库'), findsOneWidget);
        expect(find.text('回收站'), findsOneWidget);
        expect(find.text('设置'), findsOneWidget);
      },
    );
  });
}

const _macosProfile = PlatformProfile(
  platform: PlatformKind.macos,
  form: DeviceForm.desktop,
  audio: AudioCapability.dualSource,
);

const _windowsProfile = PlatformProfile(
  platform: PlatformKind.windows,
  form: DeviceForm.desktop,
  audio: AudioCapability.dualSource,
);

const _mobileProfile = PlatformProfile(
  platform: PlatformKind.android,
  form: DeviceForm.mobile,
  audio: AudioCapability.dualSource,
);

Finder _visible(WidgetTester tester, String marker) =>
    find.text(marker, skipOffstage: true).hitTestable();

Future<void> _setSurface(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pressWithModifier(
  WidgetTester tester,
  LogicalKeyboardKey modifier,
  List<LogicalKeyboardKey> keys,
) async {
  await tester.sendKeyDownEvent(modifier);
  for (final key in keys) {
    await tester.sendKeyEvent(key);
    await tester.pump();
  }
  await tester.sendKeyUpEvent(modifier);
}

Future<void> _pumpShell(
  WidgetTester tester, {
  required AppServices services,
  required PlatformProfile profile,
  required _CountingLibraryController libraryController,
  Widget? recordPage,
}) async {
  final record = recordPage ?? const _MarkerPage('record-page');
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        platformProfileProvider.overrideWithValue(profile),
        meetingLibraryProvider.overrideWith((ref) => libraryController),
      ],
      child: MaterialApp(
        theme: easyMeetingTheme(Brightness.light),
        home: HomeShell(
          screens: [
            record,
            const _MarkerPage('library-page'),
            const _MarkerPage('trash-page'),
            const _MarkerPage('settings-page'),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

class _MarkerPage extends StatelessWidget {
  const _MarkerPage(this.marker);
  final String marker;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(marker)));
  }
}

class _CounterPage extends StatefulWidget {
  const _CounterPage();

  @override
  State<_CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<_CounterPage> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('count-$count'),
            TextButton(
              onPressed: () => setState(() => count++),
              child: const Text('increment'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextFieldPage extends StatelessWidget {
  const _TextFieldPage(this.controller, this.focusNode);
  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('record-page'),
            TextField(controller: controller, focusNode: focusNode),
          ],
        ),
      ),
    );
  }
}

/// A [MeetingLibraryController] that counts `load()` calls so tests can assert
/// the shell reloads the library only when actually switching into it.
class _CountingLibraryController extends MeetingLibraryController {
  _CountingLibraryController(super.services);

  int loadCount = 0;

  @override
  Future<void> load({String query = ''}) async {
    loadCount += 1;
    state = const AsyncValue.data(<MeetingAssetBundle>[]);
  }
}

/// A no-op audio platform so [RecordingCoordinator] can be constructed in a
/// widget test without a native plugin.
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

/// Builds a real, in-memory [AppServices] for widget tests, bypassing
/// path_provider and the native audio plugin.
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
