import 'package:easy_meeting/app_services/meeting_session_state.dart';
import 'package:easy_meeting/app_services/providers.dart';
import 'package:easy_meeting/domain/models/note_template.dart';
import 'package:easy_meeting/ui/recording/live_transcript_panel.dart';
import 'package:easy_meeting/ui/recording/meeting_workspace.dart';
import 'package:easy_meeting/ui/recording/recording_screen.dart';
import 'package:easy_meeting/ui/theme/theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app_services.dart';

/// Loop 5: real-time recording workspace. Covers the presentational state
/// machine (pause/resume/highlight/degradation/transition-disabled) and the
/// R-09 platform-difference gate (no misleading live-text panel when realtime
/// is unsupported), plus the safe-end double-confirm flow driven by a real
/// session.
void main() {
  Future<void> pump(tester, MeetingWorkspace widget) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: widget)));
  }

  testWidgets('paused state relabels timer, icon and controls', (tester) async {
    await pump(
      tester,
      MeetingWorkspace(
        elapsed: const Duration(minutes: 4, seconds: 12),
        systemLevel: .5,
        microphoneLevel: .7,
        systemAudioAvailable: true,
        microphoneAvailable: true,
        isPaused: true,
        transitioning: false,
        highlightCount: 1,
        connectionLabel: '实时转写已连接',
        transcriptLines: const [],
        realtimeSupported: true,
        onPauseResume: () {},
        onStop: () {},
        onHighlight: () {},
      ),
    );
    expect(find.text('录音已暂停'), findsOneWidget);
    expect(find.text('04:12'), findsOneWidget);
    expect(find.text('继续录音'), findsOneWidget);
    expect(find.text('暂停录音'), findsNothing);
  });

  testWidgets('transition disables all recording controls', (tester) async {
    await pump(
      tester,
      MeetingWorkspace(
        elapsed: const Duration(minutes: 1),
        systemLevel: .5,
        microphoneLevel: .7,
        systemAudioAvailable: true,
        microphoneAvailable: true,
        isPaused: false,
        transitioning: true,
        highlightCount: 2,
        connectionLabel: '实时转写已连接',
        transcriptLines: const [],
        realtimeSupported: true,
        onPauseResume: () {},
        onStop: () {},
        onHighlight: () {},
      ),
    );
    // 标记重点 and 暂停 are OutlinedButton.icon; 结束 is FilledButton.icon.
    final mark = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '标记重点（2）'),
    );
    expect(mark.onPressed, isNull);
    final pause = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '暂停录音'),
    );
    expect(pause.onPressed, isNull);
    final stop = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '结束录音'),
    );
    expect(stop.onPressed, isNull);
  });

  testWidgets('degradation reason and live degraded message are shown', (
    tester,
  ) async {
    await pump(
      tester,
      MeetingWorkspace(
        elapsed: const Duration(minutes: 1),
        systemLevel: .5,
        microphoneLevel: .7,
        systemAudioAvailable: false,
        microphoneAvailable: true,
        isPaused: false,
        transitioning: false,
        highlightCount: 0,
        connectionLabel: '实时转写已中断',
        transcriptLines: const [],
        realtimeSupported: true,
        degradationReason: '系统声音不可用，本次仅录制麦克风。',
        liveDegradedMessage: '实时转写已中断，录音仍在继续',
        onPauseResume: () {},
        onStop: () {},
        onHighlight: () {},
      ),
    );
    expect(find.text('系统声音不可用，本次仅录制麦克风。'), findsOneWidget);
    expect(find.text('实时转写已中断，录音仍在继续'), findsOneWidget);
    // The degraded notice is not shown when the live stream is healthy.
  });

  testWidgets('highlight count is displayed on the mark control', (
    tester,
  ) async {
    await pump(
      tester,
      MeetingWorkspace(
        elapsed: const Duration(minutes: 1),
        systemLevel: .5,
        microphoneLevel: .7,
        systemAudioAvailable: true,
        microphoneAvailable: true,
        isPaused: false,
        transitioning: false,
        highlightCount: 3,
        connectionLabel: '实时转写已连接',
        transcriptLines: const [],
        realtimeSupported: true,
        onPauseResume: () {},
        onStop: () {},
        onHighlight: () {},
      ),
    );
    expect(find.text('标记重点（3）'), findsOneWidget);
  });

  testWidgets('realtime-supported workspace renders live-text panel', (
    tester,
  ) async {
    await pump(
      tester,
      MeetingWorkspace(
        elapsed: const Duration(minutes: 1),
        systemLevel: .5,
        microphoneLevel: .7,
        systemAudioAvailable: true,
        microphoneAvailable: true,
        isPaused: false,
        transitioning: false,
        highlightCount: 0,
        connectionLabel: '实时转写已连接',
        transcriptLines: const [
          LiveTranscriptLine(
            time: Duration(seconds: 3),
            text: '确认本周交付范围',
            isFinal: true,
            itemId: 'item-1',
          ),
        ],
        realtimeSupported: true,
        onPauseResume: () {},
        onStop: () {},
        onHighlight: () {},
      ),
    );
    expect(find.text('实时文字'), findsOneWidget);
    expect(find.text('当前平台无法实时转写'), findsNothing);
    expect(find.text('确认本周交付范围'), findsOneWidget);
  });

  group('safe-end via real session', () {
    late TestAppServices harness;

    setUp(() async {
      harness = await TestAppServices.create();
      // Start a real recording in the real async zone (file I/O + coordinator)
      // before entering the FakeAsync widget zone.
      await harness.services.session.initialize();
      await harness.services.session.startMeeting(
        MeetingStartOptions(template: NoteTemplate.builtins.first),
      );
    });

    tearDown(() async {
      await harness.dispose();
    });

    Future<void> pumpScreen(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appServicesProvider.overrideWithValue(harness.services)],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: easyMeetingTheme(Brightness.light),
            home: const RecordingScreen(),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('stop asks for confirmation; cancel keeps recording', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(
        harness.services.session.state.capturePhase,
        CapturePhase.recording,
      );
      expect(find.text('结束录音'), findsOneWidget);

      // Tap stop -> confirmation dialog appears.
      await tester.tap(find.text('结束录音'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('结束录音？'), findsOneWidget);

      // Cancel keeps recording (wait out the dialog exit animation).
      await tester.tap(find.text('继续录音'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        harness.services.session.state.capturePhase,
        CapturePhase.recording,
      );
      expect(find.text('结束录音'), findsOneWidget);

      // Confirm issues the safe stop.
      await tester.tap(find.text('结束录音'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('结束录音'),
        ),
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(AlertDialog), findsNothing);
      expect(
        harness.services.session.state.capturePhase,
        isNot(CapturePhase.recording),
      );
    });
  });
}
