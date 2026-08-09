import 'dart:io';

import 'package:easy_meeting/app_services/providers.dart';
import 'package:easy_meeting/domain/models/meeting_record.dart';
import 'package:easy_meeting/domain/models/note_template.dart';
import 'package:easy_meeting/ui/recording/recording_screen.dart';
import 'package:easy_meeting/ui/theme/theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app_services.dart';

/// Deterministic light/dark visual evidence for the Loop 4 recording-prep
/// screen (with the "recent meetings" section fed by real data) at 1080x720
/// and 880x600. Pixel-golden capture is gated behind `EM_GEN_GOLDENS=1`; the
/// default CI path is a deterministic smoke assertion.
///
/// Services are built in `setUp` (the real async zone): TestAppServices.create()
/// performs real file I/O which does NOT complete inside a testWidgets
/// FakeAsync zone. Fixed-duration pumps are used because RecordingCoordinator's
/// 250ms ticker means the screen never settles under pumpAndSettle.
void main() {
  late TestAppServices harness;

  setUp(() async {
    harness = await TestAppServices.create();
    // Seed two real meetings so the "recent meetings" section renders real data.
    await harness.services.meetings.create(
      MeetingDraft(
        id: 'm-recent',
        startedAt: DateTime(2026, 8, 9, 14, 30),
        templateSnapshot: NoteTemplate.builtins.first,
        highlights: const [],
      ),
    );
    await harness.services.meetings.create(
      MeetingDraft(
        id: 'm-older',
        startedAt: DateTime(2026, 8, 1, 9, 0),
        templateSnapshot: NoteTemplate.builtins.first,
        highlights: const [],
      ),
    );
  });

  tearDown(() async {
    await harness.dispose();
  });

  for (final width in const [1080.0, 880.0]) {
    final sizeLabel = width == 1080 ? 'extended' : 'compact';
    for (final brightness in Brightness.values) {
      final mode = brightness == Brightness.dark ? 'dark' : 'light';
      testWidgets('recording prep $sizeLabel $mode renders', (tester) async {
        tester.view.physicalSize = Size(width, 720);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appServicesProvider.overrideWithValue(harness.services),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: easyMeetingTheme(Brightness.light),
              darkTheme: easyMeetingTheme(Brightness.dark),
              themeMode: brightness == Brightness.dark
                  ? ThemeMode.dark
                  : ThemeMode.light,
              home: const RecordingScreen(),
            ),
          ),
        );
        // Fixed-duration pumps instead of pumpAndSettle: the full TestAppServices
        // harness (RecordingCoordinator's ticker) drives a continuous animation
        // that would never settle. Matches the loop2/loop3 visual tests.
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        if (Platform.environment['EM_GEN_GOLDENS'] == '1') {
          await expectLater(
            find.byType(RecordingScreen),
            matchesGoldenFile('goldens/recording-prep/$sizeLabel-$mode.png'),
          );
        } else {
          expect(tester.takeException(), isNull);
          expect(find.byType(RecordingScreen), findsOneWidget);
          // The real-data recent-meetings section renders the seeded meetings.
          expect(find.text('最近会议'), findsOneWidget);
          expect(find.text('8月9日 14:30 会议'), findsOneWidget);
        }
      });
    }
  }
}
