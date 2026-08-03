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
    expect(find.text('生成正式转写'), findsOneWidget);
    final noteButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '生成会议纪要'),
    );
    expect(noteButton.onPressed, isNull);
  });
}
