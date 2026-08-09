import 'package:easy_meeting/app_services/providers.dart';
import 'package:easy_meeting/domain/models/meeting_note.dart';
import 'package:easy_meeting/domain/models/meeting_record.dart';
import 'package:easy_meeting/domain/models/note_template.dart';
import 'package:easy_meeting/domain/models/transcript_document.dart';
import 'package:easy_meeting/ui/home_shell.dart';
import 'package:easy_meeting/ui/library/connected_meeting_library_screen.dart';
import 'package:easy_meeting/ui/library/meeting_detail_screen.dart';
import 'package:easy_meeting/ui/recording/recording_screen.dart';
import 'package:easy_meeting/ui/theme/theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app_services.dart';

/// Loop 4: the recording-prep page must be driven entirely by real data —
/// template list, realtime capability hint and, new in this loop, a "recent
/// meetings" section fed by meetingLibraryProvider. A recent-meeting tap is a
/// deep-link that switches the shell to the library and preselects that meeting.
void main() {
  late TestAppServices harness;

  setUp(() async {
    harness = await TestAppServices.create();
  });

  tearDown(() async {
    await harness.dispose();
  });

  Future<void> pumpPrep(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appServicesProvider.overrideWithValue(harness.services)],
        child: const MaterialApp(home: RecordingScreen()),
      ),
    );
    // Fixed-duration pumps: RecordingCoordinator's ticker means the full
    // AppServices harness never settles (matches loop2/loop3 visual tests).
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> seedTwoMeetings() async {
    // Use local DateTimes so meetingDisplayTitle's toLocal() is an identity and
    // the rendered title matches the asserted text on any host timezone.
    final meetings = harness.services.meetings;
    await meetings.create(
      MeetingDraft(
        id: 'm-recent',
        startedAt: DateTime(2026, 8, 9, 14, 30),
        templateSnapshot: NoteTemplate.builtins.first,
        highlights: const [],
      ),
    );
    await meetings.create(
      MeetingDraft(
        id: 'm-older',
        startedAt: DateTime(2026, 8, 1, 9, 0),
        templateSnapshot: NoteTemplate.builtins.first,
        highlights: const [],
      ),
    );
  }

  test('recentMeetingAssetStatus reflects real asset presence', () {
    MeetingAssetBundle bundle({MeetingNote? note}) => MeetingAssetBundle(
      meeting: _meeting,
      note: note,
      transcript: _transcript,
    );
    // No assets.
    expect(recentMeetingAssetStatus(MeetingAssetBundle(meeting: _meeting)), (
      '新会议',
      false,
    ));
    // Transcript only -> 转写就绪.
    expect(
      recentMeetingAssetStatus(
        MeetingAssetBundle(meeting: _meeting, transcript: _transcript),
      ),
      ('转写就绪', true),
    );
    // Note (most advanced) -> 纪要就绪, even with a transcript present.
    expect(recentMeetingAssetStatus(bundle(note: _note)), ('纪要就绪', true));
  });

  testWidgets('prep renders template, realtime and start from real data', (
    tester,
  ) async {
    await pumpPrep(tester);
    expect(find.text('准备记录下一场会议'), findsOneWidget);
    expect(find.text('纪要模板'), findsOneWidget);
    expect(find.text('会议中显示实时文字'), findsOneWidget);
    expect(find.text('开始录音'), findsOneWidget);
    // Template dropdown lists the real built-in templates.
    final dropdown = tester.widget<DropdownButton<NoteTemplate>>(
      find.byType(DropdownButton<NoteTemplate>),
    );
    expect(dropdown.items, hasLength(NoteTemplate.builtins.length));
  });

  testWidgets('recent meetings section renders real meetings', (tester) async {
    await seedTwoMeetings();
    await pumpPrep(tester);
    expect(find.text('最近会议'), findsOneWidget);
    expect(find.text('8月9日 14:30 会议'), findsOneWidget);
    expect(find.text('8月1日 09:00 会议'), findsOneWidget);
    // Neither meeting has assets yet -> both are "新会议".
    expect(find.text('新会议'), findsNWidgets(2));
  });

  testWidgets('recent meeting tap sets the deep-link provider', (tester) async {
    await seedTwoMeetings();
    await pumpPrep(tester);
    await tester.tap(find.text('8月9日 14:30 会议'));
    await tester.pump();
    String? deepLink;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appServicesProvider.overrideWithValue(harness.services)],
        child: Builder(
          builder: (context) {
            deepLink = ProviderScope.containerOf(
              context,
            ).read(selectedMeetingIdProvider);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(deepLink, 'm-recent');
  });

  testWidgets('deep-link switches shell to library and preselects', (
    tester,
  ) async {
    await seedTwoMeetings();
    tester.view.physicalSize = const Size(1200, 720);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appServicesProvider.overrideWithValue(harness.services)],
        child: MaterialApp(
          theme: easyMeetingTheme(Brightness.light),
          home: HomeShell(
            screens: const [
              RecordingScreen(),
              ConnectedMeetingLibraryScreen(),
              SizedBox.shrink(),
              SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('最近会议'), findsOneWidget);
    // Deep-link to the OLDER meeting (8月1日): it is the second library item, so
    // a correct preselect is distinguishable from the default first-item fallback.
    await tester.tap(find.text('8月1日 09:00 会议'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    // The shell switched to the library tab.
    expect(find.text('会议库'), findsWidgets);
    // The wide detail pane shows the deep-linked meeting, NOT the first item.
    final detail = tester.widget<MeetingDetailScreen>(
      find.byType(MeetingDetailScreen),
    );
    expect(detail.meeting.id, 'm-older');
  });
}

final _meeting = MeetingRecord(
  id: 'm',
  startedAt: DateTime.utc(2026, 8, 9, 14, 30),
  duration: Duration.zero,
  templateSnapshot: NoteTemplate.builtins.first,
  highlights: const [],
  status: MeetingStatus.recorded,
  createdAt: DateTime.utc(2026, 8, 9, 14, 30),
  updatedAt: DateTime.utc(2026, 8, 9, 14, 30),
);

final _note = MeetingNote(
  id: 'note-1',
  title: '纪要',
  startedAt: DateTime.utc(2026, 8, 9, 14, 30),
  duration: Duration.zero,
  audioPath: '',
  transcriptPath: '',
  templateId: NoteTemplate.builtins.first.id,
  sections: const [],
  todos: const [],
  highlights: const [],
  meetingId: 'm',
);

final _transcript = TranscriptDocument(
  id: 'transcript-1',
  meetingId: 'm',
  kind: TranscriptKind.finalTranscript,
  status: TranscriptStatus.ready,
  coveredDuration: Duration.zero,
  revision: 1,
  createdAt: DateTime.utc(2026, 8, 9, 14, 31),
  updatedAt: DateTime.utc(2026, 8, 9, 14, 31),
);
