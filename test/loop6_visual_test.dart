import 'dart:io';

import 'package:easy_meeting/domain/models/asset_status.dart';
import 'package:easy_meeting/domain/models/meeting_note.dart';
import 'package:easy_meeting/domain/models/meeting_record.dart';
import 'package:easy_meeting/domain/models/note_template.dart';
import 'package:easy_meeting/domain/models/recording_asset.dart';
import 'package:easy_meeting/domain/models/transcript_document.dart';
import 'package:easy_meeting/ui/library/meeting_library_screen.dart';
import 'package:easy_meeting/ui/theme/theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Deterministic light/dark visual evidence for the Loop 6 meeting library at
/// extended (1080x720) and narrower (880x600) sizes, showing projected asset
/// states (missing / damaged / playable recording; ready / processing / failed
/// note). Pixel-golden capture is gated behind `EM_GEN_GOLDENS=1`; the default
/// CI path is a deterministic smoke assertion.
void main() {
  MeetingLibraryScreen library() => MeetingLibraryScreen(
    items: [
      MeetingLibraryItem(
        meeting: MeetingRecord(
          id: 'm-ready',
          startedAt: DateTime(2026, 8, 9, 14, 30),
          duration: const Duration(minutes: 63),
          status: MeetingStatus.recorded,
          createdAt: DateTime(2026, 8, 9, 14, 30),
          updatedAt: DateTime(2026, 8, 9, 15, 30),
          templateSnapshot: NoteTemplate.builtins.first,
          highlights: const [Duration(seconds: 30)],
        ),
        recordingStatus: RecordingDisplayStatus.playable,
        note: MeetingNote(
          id: 'n-ready',
          title: '产品评审纪要',
          startedAt: DateTime(2026, 8, 9, 14, 30),
          duration: const Duration(minutes: 63),
          audioPath: 'a.wav',
          transcriptPath: 't.txt',
          templateId: NoteTemplate.builtins.first.id,
          sections: const [NoteSection(heading: '结论', content: '本轮发布范围确认通过')],
          todos: const [],
          highlights: const [],
          meetingId: 'm-ready',
        ),
        noteStatus: MeetingNoteDisplayStatus.ready,
        transcript: TranscriptDocument(
          id: 't-ready',
          meetingId: 'm-ready',
          kind: TranscriptKind.finalTranscript,
          status: TranscriptStatus.ready,
          bodyPath: 't.txt',
          revision: 1,
          createdAt: DateTime(2026, 8, 9, 15, 0),
          updatedAt: DateTime(2026, 8, 9, 15, 0),
          coveredDuration: const Duration(minutes: 63),
        ),
      ),
      MeetingLibraryItem(
        meeting: MeetingRecord(
          id: 'm-processing',
          startedAt: DateTime(2026, 8, 8, 10, 0),
          duration: const Duration(minutes: 42),
          status: MeetingStatus.recorded,
          createdAt: DateTime(2026, 8, 8, 10, 0),
          updatedAt: DateTime(2026, 8, 8, 10, 42),
          templateSnapshot: NoteTemplate.builtins.first,
          highlights: const [],
        ),
        recordingStatus: RecordingDisplayStatus.playable,
        noteStatus: MeetingNoteDisplayStatus.processing,
      ),
      MeetingLibraryItem(
        meeting: MeetingRecord(
          id: 'm-damaged',
          startedAt: DateTime(2026, 8, 7, 9, 0),
          duration: const Duration(minutes: 20),
          status: MeetingStatus.recorded,
          createdAt: DateTime(2026, 8, 7, 9, 0),
          updatedAt: DateTime(2026, 8, 7, 9, 20),
          templateSnapshot: NoteTemplate.builtins.first,
          highlights: const [],
        ),
        recordingStatus: RecordingDisplayStatus.damaged,
        noteStatus: MeetingNoteDisplayStatus.failed,
      ),
    ],
  );

  for (final size in const [Size(1080, 720), Size(880, 600)]) {
    final sizeLabel = size.width >= 1000 ? 'extended' : 'narrow';
    for (final brightness in Brightness.values) {
      final mode = brightness == Brightness.dark ? 'dark' : 'light';
      testWidgets('library $sizeLabel $mode renders', (tester) async {
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
            home: Scaffold(body: library()),
          ),
        );
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        if (Platform.environment['EM_GEN_GOLDENS'] == '1') {
          await expectLater(
            find.byType(MeetingLibraryScreen),
            matchesGoldenFile('goldens/library/$sizeLabel-$mode.png'),
          );
        } else {
          expect(tester.takeException(), isNull);
          expect(find.text('会议库'), findsOneWidget);
          expect(find.text('产品评审纪要'), findsWidgets);
          expect(find.text('录音 损坏'), findsOneWidget);
          expect(find.text('纪要 失败'), findsOneWidget);
        }
      });
    }
  }
}
