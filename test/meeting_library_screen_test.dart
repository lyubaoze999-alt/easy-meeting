import 'package:easy_meeting/domain/models/meeting_note.dart';
import 'package:easy_meeting/domain/models/meeting_record.dart';
import 'package:easy_meeting/domain/models/note_template.dart';
import 'package:easy_meeting/domain/models/recording_asset.dart';
import 'package:easy_meeting/domain/models/transcript_document.dart';
import 'package:easy_meeting/ui/library/meeting_detail_screen.dart';
import 'package:easy_meeting/ui/library/meeting_library_screen.dart';
import 'package:easy_meeting/ui/theme/theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('desktop keeps meeting list and selected detail side by side', (
    tester,
  ) async {
    MeetingRecord? selected;
    final first = _completeItem();
    final secondMeeting = _meeting(
      id: 'meeting-2',
      startedAt: DateTime(2026, 8, 2, 9),
    );
    final second = MeetingLibraryItem(
      meeting: secondMeeting,
      recordingStatus: RecordingDisplayStatus.damaged,
      transcript: _transcript(
        meetingId: secondMeeting.id,
        status: TranscriptStatus.needsRepair,
      ),
      noteStatus: MeetingNoteDisplayStatus.failed,
    );

    await _pumpLibrary(
      tester,
      size: const Size(1200, 820),
      screen: MeetingLibraryScreen(
        items: [first, second],
        onMeetingSelected: (meeting) => selected = meeting,
      ),
    );

    expect(find.text('会议库'), findsOneWidget);
    expect(find.text('产品评审'), findsNWidgets(2));
    expect(find.text('录音 损坏'), findsOneWidget);
    expect(find.text('转写 需补全'), findsOneWidget);
    expect(find.text('纪要 失败'), findsOneWidget);
    expect(find.byType(VerticalDivider), findsOneWidget);
    expect(find.text('录音'), findsOneWidget);
    expect(find.text('转写'), findsOneWidget);
    expect(find.text('纪要'), findsOneWidget);

    await tester.tap(find.text('8月2日 09:00 会议').first);
    await tester.pumpAndSettle();

    expect(selected?.id, 'meeting-2');
    expect(find.text('8月2日 09:00 会议'), findsNWidgets(2));
    expect(find.text('录音文件损坏'), findsOneWidget);
  });

  testWidgets('mobile opens a meeting detail route from the list', (
    tester,
  ) async {
    final item = _completeItem();
    await _pumpLibrary(
      tester,
      size: const Size(390, 844),
      screen: MeetingLibraryScreen(items: [item]),
    );

    expect(find.text('会议详情'), findsNothing);
    expect(find.text('转写正文'), findsNothing);

    await tester.tap(find.text('产品评审'));
    await tester.pumpAndSettle();

    expect(find.text('会议详情'), findsOneWidget);
    expect(find.text('录音'), findsOneWidget);
    expect(find.text('转写'), findsOneWidget);
    expect(find.text('纪要'), findsOneWidget);

    await tester.tap(find.text('转写'));
    await tester.pumpAndSettle();
    expect(find.text('转写正文'), findsOneWidget);
    expect(find.text('移动端也展示只读正文。'), findsOneWidget);
  });

  testWidgets('list exposes all required transcript status copy', (
    tester,
  ) async {
    final statuses = <TranscriptDocument?>[
      null,
      _transcript(
        meetingId: 'meeting-1',
        status: TranscriptStatus.collecting,
        kind: TranscriptKind.realtimeDraft,
      ),
      _transcript(meetingId: 'meeting-2', status: TranscriptStatus.needsRepair),
      _transcript(meetingId: 'meeting-3', status: TranscriptStatus.processing),
      _transcript(meetingId: 'meeting-4', status: TranscriptStatus.ready),
      _transcript(meetingId: 'meeting-5', status: TranscriptStatus.failed),
    ];
    final items = List.generate(statuses.length, (index) {
      final meeting = _meeting(
        id: 'meeting-$index',
        startedAt: DateTime(2026, 8, index + 1, 10),
      );
      return MeetingLibraryItem(meeting: meeting, transcript: statuses[index]);
    });

    await _pumpLibrary(
      tester,
      size: const Size(600, 1200),
      screen: MeetingLibraryScreen(items: items),
    );

    expect(find.text('转写 未生成'), findsOneWidget);
    expect(find.text('转写 实时草稿'), findsOneWidget);
    expect(find.text('转写 需补全'), findsOneWidget);
    expect(find.text('转写 处理中'), findsOneWidget);
    expect(find.text('转写 已完成'), findsOneWidget);
    expect(find.text('转写 失败'), findsOneWidget);
  });

  testWidgets('empty library uses meeting-level copy', (tester) async {
    await _pumpLibrary(
      tester,
      size: const Size(1000, 700),
      screen: const MeetingLibraryScreen(items: []),
    );

    expect(find.text('还没有会议'), findsOneWidget);
    expect(find.text('完成录音后，会议及其独立资产会显示在这里。'), findsOneWidget);
  });
}

Future<void> _pumpLibrary(
  WidgetTester tester, {
  required Size size,
  required MeetingLibraryScreen screen,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(theme: easyMeetingTheme(Brightness.light), home: screen),
  );
  await tester.pump();
}

MeetingLibraryItem _completeItem() {
  final meeting = _meeting(
    id: 'meeting-1',
    startedAt: DateTime(2026, 8, 3, 10, 30),
  );
  return MeetingLibraryItem(
    meeting: meeting,
    recording: _recording(meeting.id),
    transcript: _transcript(
      meetingId: meeting.id,
      status: TranscriptStatus.ready,
    ),
    transcriptText: '移动端也展示只读正文。',
    note: _note(meeting.id),
  );
}

MeetingRecord _meeting({required String id, required DateTime startedAt}) {
  return MeetingRecord(
    id: id,
    startedAt: startedAt,
    endedAt: startedAt.add(const Duration(minutes: 38)),
    duration: const Duration(minutes: 38),
    templateSnapshot: NoteTemplate.builtins.first,
    highlights: const [],
    status: MeetingStatus.recorded,
    createdAt: startedAt,
    updatedAt: startedAt,
  );
}

RecordingAsset _recording(String meetingId) {
  final createdAt = DateTime(2026, 8, 3, 10, 30);
  return RecordingAsset(
    id: 'recording-$meetingId',
    meetingId: meetingId,
    path: '/private/$meetingId.wav',
    mimeType: 'audio/wav',
    sampleRate: 48000,
    channels: 2,
    duration: const Duration(minutes: 38),
    byteLength: 40 * 1024 * 1024,
    sha256: null,
    sourceProfile: AudioCaptureProfile.microphoneOnly,
    finalizedAt: createdAt,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

TranscriptDocument _transcript({
  required String meetingId,
  required TranscriptStatus status,
  TranscriptKind kind = TranscriptKind.finalTranscript,
}) {
  final createdAt = DateTime(2026, 8, 3, 10, 30);
  return TranscriptDocument(
    id: 'transcript-$meetingId-${status.name}',
    meetingId: meetingId,
    kind: kind,
    status: status,
    language: 'zh-CN',
    coveredDuration: const Duration(minutes: 38),
    revision: 1,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
}

MeetingNote _note(String meetingId) {
  return MeetingNote(
    id: 'note-$meetingId',
    meetingId: meetingId,
    transcriptId: 'transcript-$meetingId',
    title: '产品评审',
    startedAt: DateTime(2026, 8, 3, 10, 30),
    duration: const Duration(minutes: 38),
    audioPath: '/private/$meetingId.wav',
    transcriptPath: '/private/$meetingId.txt',
    templateId: 'builtin.review',
    sections: const [NoteSection(heading: '结论', content: '继续推进。')],
    todos: const [],
    highlights: const [],
  );
}
