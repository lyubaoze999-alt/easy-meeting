import 'dart:io';

import 'package:easy_meeting/domain/models/meeting_note.dart';
import 'package:easy_meeting/domain/models/meeting_record.dart';
import 'package:easy_meeting/domain/models/note_template.dart';
import 'package:easy_meeting/domain/models/recording_asset.dart';
import 'package:easy_meeting/domain/models/transcript_document.dart';
import 'package:easy_meeting/ui/library/meeting_detail_screen.dart';
import 'package:easy_meeting/ui/theme/theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Deterministic light/dark visual evidence for the Loop 7 meeting detail at
/// extended (1080x720) and narrower (880x600) sizes. With a ready note the
/// detail defaults to the 纪要 tab (R-03 companion); the recording tab now
/// offers an explicit external-play action instead of a non-functional slider.
/// Pixel-golden capture is gated behind `EM_GEN_GOLDENS=1`; the default CI path
/// is a deterministic smoke assertion.
void main() {
  final startedAt = DateTime(2026, 8, 9, 14, 30);

  MeetingDetailScreen detail() => MeetingDetailScreen(
    meeting: MeetingRecord(
      id: 'm-detail',
      startedAt: startedAt,
      endedAt: startedAt.add(const Duration(minutes: 63)),
      duration: const Duration(minutes: 63),
      status: MeetingStatus.recorded,
      createdAt: startedAt,
      updatedAt: startedAt.add(const Duration(minutes: 63)),
      templateSnapshot: NoteTemplate.builtins.first,
      highlights: const [Duration(seconds: 30)],
    ),
    recording: RecordingAsset(
      id: 'r-detail',
      meetingId: 'm-detail',
      path: 'audio.wav',
      mimeType: 'audio/wav',
      sampleRate: 48000,
      channels: 2,
      duration: const Duration(minutes: 63),
      byteLength: 52 * 1024 * 1024,
      sha256: 'digest',
      sourceProfile: AudioCaptureProfile.dualSource,
      finalizedAt: startedAt.add(const Duration(minutes: 63)),
      createdAt: startedAt,
      updatedAt: startedAt,
    ),
    recordingStatus: RecordingDisplayStatus.playable,
    transcript: TranscriptDocument(
      id: 't-detail',
      meetingId: 'm-detail',
      kind: TranscriptKind.finalTranscript,
      status: TranscriptStatus.ready,
      language: 'zh-CN',
      coveredDuration: const Duration(minutes: 63),
      revision: 1,
      createdAt: startedAt,
      updatedAt: startedAt,
    ),
    note: MeetingNote(
      id: 'n-detail',
      meetingId: 'm-detail',
      transcriptId: 't-detail',
      title: '产品评审纪要',
      startedAt: startedAt,
      duration: const Duration(minutes: 63),
      audioPath: 'audio.wav',
      transcriptPath: 'transcript.txt',
      templateId: NoteTemplate.builtins.first.id,
      sections: const [
        NoteSection(heading: '结论', content: '本轮发布范围确认通过，接口周五联调。'),
      ],
      todos: const [TodoItem(text: '补齐移动端验收', owner: '小王')],
      highlights: const [],
      visuals: const NoteVisuals(
        keyNumbers: [KeyNumber(label: '参会人', value: '8')],
      ),
    ),
    noteStatus: MeetingNoteDisplayStatus.ready,
  );

  for (final size in const [Size(1080, 720), Size(880, 600)]) {
    final sizeLabel = size.width >= 1000 ? 'extended' : 'narrow';
    for (final brightness in Brightness.values) {
      final mode = brightness == Brightness.dark ? 'dark' : 'light';
      testWidgets('detail $sizeLabel $mode renders', (tester) async {
        tester.view.physicalSize = size;
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
            home: Scaffold(body: detail()),
          ),
        );
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        if (Platform.environment['EM_GEN_GOLDENS'] == '1') {
          await expectLater(
            find.byType(MeetingDetailScreen),
            matchesGoldenFile('goldens/detail/$sizeLabel-$mode.png'),
          );
        } else {
          expect(tester.takeException(), isNull);
          expect(find.text('产品评审纪要'), findsOneWidget);
          expect(find.text('结论'), findsOneWidget);
        }
      });
    }
  }
}
