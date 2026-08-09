import 'dart:io';

import 'package:easy_meeting/ui/recording/live_transcript_panel.dart';
import 'package:easy_meeting/ui/recording/meeting_workspace.dart';
import 'package:easy_meeting/ui/theme/theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Deterministic light/dark visual evidence for the Loop 5 recording workspace
/// (with realtime) at extended/narrow widths, plus the R-09 local-only notice
/// for platforms without realtime PCM. Pixel-golden capture is gated behind
/// `EM_GEN_GOLDENS=1`; the default CI path is a deterministic smoke assertion.
void main() {
  MeetingWorkspace workspace({required bool realtimeSupported}) =>
      MeetingWorkspace(
        elapsed: const Duration(minutes: 27, seconds: 41),
        systemLevel: .45,
        microphoneLevel: .72,
        systemAudioAvailable: true,
        microphoneAvailable: true,
        isPaused: false,
        transitioning: false,
        highlightCount: 3,
        connectionLabel: '实时转写已连接',
        transcriptLines: realtimeSupported
            ? const [
                LiveTranscriptLine(
                  time: Duration(seconds: 3),
                  text: '确认本周交付范围',
                  isFinal: true,
                  itemId: 'item-1',
                ),
                LiveTranscriptLine(
                  time: Duration(seconds: 9),
                  text: '后端接口今天下午联调',
                  isFinal: false,
                  itemId: 'item-2',
                ),
              ]
            : const [],
        realtimeSupported: realtimeSupported,
        degradationReason: null,
        onPauseResume: () {},
        onStop: () {},
        onHighlight: () {},
      );

  for (final width in const [1080.0, 680.0]) {
    final sizeLabel = width >= 760 ? 'extended' : 'compact';
    for (final brightness in Brightness.values) {
      final mode = brightness == Brightness.dark ? 'dark' : 'light';
      testWidgets('workspace realtime $sizeLabel $mode renders', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 720);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: easyMeetingTheme(Brightness.light),
            darkTheme: easyMeetingTheme(Brightness.dark),
            themeMode: brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            home: Scaffold(body: workspace(realtimeSupported: true)),
          ),
        );
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        if (Platform.environment['EM_GEN_GOLDENS'] == '1') {
          await expectLater(
            find.byType(MeetingWorkspace),
            matchesGoldenFile(
              'goldens/recording-workspace/realtime-$sizeLabel'
              '-$mode.png',
            ),
          );
        } else {
          expect(tester.takeException(), isNull);
          expect(find.text('正在录音'), findsOneWidget);
          expect(find.text('实时文字'), findsOneWidget);
          expect(find.text('结束录音'), findsOneWidget);
        }
      });
    }
  }

  for (final width in const [1080.0, 680.0]) {
    final sizeLabel = width >= 760 ? 'extended' : 'compact';
    for (final brightness in Brightness.values) {
      final mode = brightness == Brightness.dark ? 'dark' : 'light';
      testWidgets('workspace local-only $sizeLabel $mode renders (no live '
          'panel)', (tester) async {
        tester.view.physicalSize = Size(width, 720);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: easyMeetingTheme(Brightness.light),
            darkTheme: easyMeetingTheme(Brightness.dark),
            themeMode: brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            home: Scaffold(body: workspace(realtimeSupported: false)),
          ),
        );
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        if (Platform.environment['EM_GEN_GOLDENS'] == '1') {
          await expectLater(
            find.byType(MeetingWorkspace),
            matchesGoldenFile(
              'goldens/recording-workspace/local-only-$sizeLabel-$mode.png',
            ),
          );
        } else {
          expect(tester.takeException(), isNull);
          expect(find.text('当前平台无法实时转写'), findsOneWidget);
          expect(find.text('实时文字'), findsNothing);
          expect(find.text('结束录音'), findsOneWidget);
        }
      });
    }
  }
}
