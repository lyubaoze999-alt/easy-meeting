import 'package:easy_meeting/domain/models/meeting_note.dart';
import 'package:easy_meeting/domain/models/meeting_record.dart';
import 'package:easy_meeting/domain/models/note_template.dart';
import 'package:easy_meeting/domain/models/recording_asset.dart';
import 'package:easy_meeting/domain/models/transcript_document.dart';
import 'package:easy_meeting/ui/library/meeting_detail_screen.dart';
import 'package:easy_meeting/ui/theme/theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'recording actions stay callback-driven and deletion is isolated',
    (tester) async {
      var recordingDeletes = 0;
      var transcriptDeletes = 0;
      var noteDeletes = 0;
      var plays = 0;

      await _pumpDetail(
        tester,
        MeetingDetailScreen(
          meeting: _meeting(),
          recording: _recording(),
          transcript: _transcript(status: TranscriptStatus.ready),
          note: _note(),
          onPlayRecording: () => plays++,
          onDeleteRecording: () => recordingDeletes++,
          onDeleteTranscript: () => transcriptDeletes++,
          onDeleteNote: () => noteDeletes++,
        ),
      );

      expect(find.text('系统声音 + 麦克风'), findsOneWidget);
      expect(find.text('52.0 MB'), findsOneWidget);

      await tester.tap(find.byTooltip('播放'));
      expect(plays, 1);

      await tester.tap(find.text('删除录音'));
      await tester.pumpAndSettle();
      expect(find.text('删除录音？'), findsOneWidget);
      expect(find.text('只会删除录音，不会删除转写和纪要。删除后将失去播放、导出和重新转写能力。'), findsOneWidget);
      expect(recordingDeletes, 0);

      await tester.tap(find.text('确认删除录音'));
      await tester.pumpAndSettle();
      expect(recordingDeletes, 1);
      expect(transcriptDeletes, 0);
      expect(noteDeletes, 0);
      expect(find.byType(SnackBar), findsNothing);

      await tester.tap(find.text('转写'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('删除转写'));
      await tester.pumpAndSettle();
      expect(find.text('只会删除转写，不会删除录音。现有纪要不会同步变化。'), findsOneWidget);
      await tester.tap(find.text('确认删除转写'));
      await tester.pumpAndSettle();
      expect(transcriptDeletes, 1);
      expect(recordingDeletes, 1);
      expect(noteDeletes, 0);
    },
  );

  testWidgets(
    'transcript tab renders states metadata body and retry callback',
    (tester) async {
      var repairs = 0;
      final transcript = _transcript(status: TranscriptStatus.needsRepair);

      await _pumpDetail(
        tester,
        MeetingDetailScreen(
          meeting: _meeting(),
          recording: _recording(),
          transcript: transcript,
          transcriptText: '这是一段只读转写正文。',
          onRepairTranscript: () => repairs++,
        ),
      );

      await tester.tap(find.text('转写'));
      await tester.pumpAndSettle();

      expect(find.text('需补全'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
      expect(find.text('zh-CN'), findsOneWidget);
      expect(find.text('正式转写'), findsOneWidget);
      expect(find.text('这是一段只读转写正文。'), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);

      await tester.tap(find.text('补全转写'));
      expect(repairs, 1);
    },
  );

  testWidgets(
    'note tab is read-only and delegates export and isolated delete',
    (tester) async {
      var exports = 0;
      var noteDeletes = 0;
      var transcriptDeletes = 0;

      await _pumpDetail(
        tester,
        MeetingDetailScreen(
          meeting: _meeting(),
          transcript: _transcript(status: TranscriptStatus.ready),
          note: _note(),
          onExportNoteMarkdown: () => exports++,
          onDeleteNote: () => noteDeletes++,
          onDeleteTranscript: () => transcriptDeletes++,
        ),
      );

      await tester.tap(find.text('纪要'));
      await tester.pumpAndSettle();

      expect(find.text('关键结论'), findsOneWidget);
      expect(find.text('使用独立资产生命周期。'), findsOneWidget);
      expect(find.text('待办事项'), findsOneWidget);
      expect(find.text('补齐移动端验收'), findsOneWidget);
      expect(find.text('图文概览'), findsOneWidget);
      expect(find.text('参会人：8'), findsOneWidget);
      final todo = tester.widget<CheckboxListTile>(
        find.widgetWithText(CheckboxListTile, '补齐移动端验收'),
      );
      expect(todo.onChanged, isNull);

      await tester.tap(find.text('导出 Markdown'));
      expect(exports, 1);
      expect(find.byType(SnackBar), findsNothing);

      await tester.tap(find.text('删除纪要'));
      await tester.pumpAndSettle();
      expect(find.text('只会删除纪要，不会删除转写和录音。'), findsOneWidget);
      await tester.tap(find.text('确认删除纪要'));
      await tester.pumpAndSettle();
      expect(noteDeletes, 1);
      expect(transcriptDeletes, 0);
    },
  );

  testWidgets('unwired recording capabilities are visibly disabled', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      MeetingDetailScreen(meeting: _meeting(), recording: _recording()),
    );

    final reveal = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '在文件夹中显示'),
    );
    final export = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '导出录音'),
    );
    expect(reveal.onPressed, isNull);
    expect(export.onPressed, isNull);
    expect(find.byTooltip('播放'), findsOneWidget);
  });
}

Future<void> _pumpDetail(
  WidgetTester tester,
  MeetingDetailScreen detail,
) async {
  tester.view.physicalSize = const Size(1100, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: easyMeetingTheme(Brightness.light),
      home: Scaffold(body: detail),
    ),
  );
  await tester.pump();
}

MeetingRecord _meeting({String id = 'meeting-1'}) {
  final startedAt = DateTime(2026, 8, 3, 10, 30);
  return MeetingRecord(
    id: id,
    startedAt: startedAt,
    endedAt: startedAt.add(const Duration(minutes: 42)),
    duration: const Duration(minutes: 42),
    templateSnapshot: NoteTemplate.builtins.first,
    highlights: const [Duration(minutes: 3)],
    status: MeetingStatus.recorded,
    createdAt: startedAt,
    updatedAt: startedAt,
  );
}

RecordingAsset _recording() {
  final createdAt = DateTime(2026, 8, 3, 10, 30);
  return RecordingAsset(
    id: 'recording-1',
    meetingId: 'meeting-1',
    path: '/private/meeting.wav',
    mimeType: 'audio/wav',
    sampleRate: 48000,
    channels: 2,
    duration: const Duration(minutes: 42),
    byteLength: 52 * 1024 * 1024,
    sha256: 'digest',
    sourceProfile: AudioCaptureProfile.dualSource,
    finalizedAt: createdAt.add(const Duration(minutes: 42)),
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

TranscriptDocument _transcript({required TranscriptStatus status}) {
  final createdAt = DateTime(2026, 8, 3, 10, 30);
  return TranscriptDocument(
    id: 'transcript-1',
    meetingId: 'meeting-1',
    kind: TranscriptKind.finalTranscript,
    status: status,
    language: 'zh-CN',
    coveredDuration: const Duration(minutes: 21),
    revision: 2,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

MeetingNote _note() {
  return MeetingNote(
    id: 'note-1',
    meetingId: 'meeting-1',
    transcriptId: 'transcript-1',
    title: '产品评审',
    startedAt: DateTime(2026, 8, 3, 10, 30),
    duration: const Duration(minutes: 42),
    audioPath: '/private/meeting.wav',
    transcriptPath: '/private/transcript.txt',
    templateId: 'builtin.review',
    sections: const [NoteSection(heading: '关键结论', content: '使用独立资产生命周期。')],
    todos: const [TodoItem(text: '补齐移动端验收', owner: '小王')],
    highlights: const [],
    visuals: const NoteVisuals(
      keyNumbers: [KeyNumber(label: '参会人', value: '8')],
    ),
  );
}
