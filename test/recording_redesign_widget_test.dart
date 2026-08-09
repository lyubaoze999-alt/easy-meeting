import 'package:easy_meeting/ui/recording/live_transcript_panel.dart';
import 'package:easy_meeting/ui/recording/meeting_workspace.dart';
import 'package:easy_meeting/ui/recording/recording_saved_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('meeting workspace stops recording without promising AI work', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MeetingWorkspace(
            elapsed: const Duration(minutes: 12),
            systemLevel: .5,
            microphoneLevel: .7,
            systemAudioAvailable: true,
            microphoneAvailable: true,
            isPaused: false,
            transitioning: false,
            highlightCount: 2,
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
        ),
      ),
    );

    expect(find.text('结束录音'), findsOneWidget);
    expect(find.text('结束并生成纪要'), findsNothing);
    expect(find.text('确认本周交付范围'), findsOneWidget);
  });

  // R-09: on a platform without realtime PCM (Windows), the workspace must not
  // render a misleading empty "实时文字" panel; it shows a capability notice.
  testWidgets('R-09 workspace without realtime shows local-only notice, not '
      'live-text panel', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MeetingWorkspace(
            elapsed: const Duration(minutes: 1),
            systemLevel: .4,
            microphoneLevel: .6,
            systemAudioAvailable: true,
            microphoneAvailable: true,
            isPaused: false,
            transitioning: false,
            highlightCount: 0,
            connectionLabel: '未开启实时转写',
            transcriptLines: const [],
            realtimeSupported: false,
            onPauseResume: () {},
            onStop: () {},
            onHighlight: () {},
          ),
        ),
      ),
    );

    // No misleading live-text panel.
    expect(find.text('实时文字'), findsNothing);
    expect(find.text('等待声音…\n本地录音会独立保存，不受实时服务影响。'), findsNothing);
    // Capability notice is shown and recording controls remain.
    expect(find.text('当前平台无法实时转写'), findsOneWidget);
    expect(find.text('结束录音'), findsOneWidget);
    expect(find.text('暂停录音'), findsOneWidget);
  });

  testWidgets('saved recording blocks summary until final transcript exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecordingSavedPanel(
            duration: const Duration(minutes: 38, seconds: 21),
            byteLength: 43 * 1024 * 1024,
            sourceLabel: '系统声音 + 麦克风',
            transcriptStatus: SavedTranscriptStatus.missing,
            onPlay: () {},
            onReveal: () {},
            onGenerateTranscript: () {},
            onGenerateNote: () {},
            onNextMeeting: () {},
          ),
        ),
      ),
    );

    expect(find.text('录音已安全保存'), findsOneWidget);
    expect(find.text('纪要已生成'), findsNothing);
    expect(find.text('生成正式转写'), findsOneWidget);
    final noteButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '生成会议纪要'),
    );
    expect(noteButton.onPressed, isNull);
  });
}
