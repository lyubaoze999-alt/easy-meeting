import 'dart:io';

import 'package:easy_meeting/app_services/providers.dart';
import 'package:easy_meeting/domain/models/meeting_record.dart';
import 'package:easy_meeting/domain/models/note_template.dart';
import 'package:easy_meeting/domain/models/recording_asset.dart';
import 'package:easy_meeting/ui/settings/settings_screen.dart';
import 'package:easy_meeting/ui/theme/theme_tokens.dart';
import 'package:easy_meeting/ui/trash/trash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_app_services.dart';
import 'test_audio.dart';

/// Deterministic light/dark visual evidence for the Loop 8 settings and trash
/// screens at extended (1080x720) and narrower (880x600) sizes. The trash
/// screen is exercised populated (one trashed meeting) so its cards render.
/// Pixel-golden capture is gated behind `EM_GEN_GOLDENS=1`; the default CI path
/// is a deterministic smoke assertion (no overflow, key text present).
///
/// The harness (real file + Drift DB + Job queue) is built in `setUp`, which
/// runs outside the widget-test FakeAsync zone where real I/O would hang. The
/// settings screens need SharedPreferences + secure storage mocked so the
/// settings form (not an error/loading state) renders.
void main() {
  late TestAppServices harness;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    harness = await TestAppServices.create();
    // Seed one recorded, then trashed, meeting so the trash screen shows its
    // cards (a meeting cannot be trashed while still in recording status).
    await harness.services.meetings.create(
      MeetingDraft(
        id: 'm-trash',
        startedAt: DateTime(2026, 8, 9, 14, 30),
        templateSnapshot: NoteTemplate.builtins.first,
        highlights: const [],
      ),
    );
    final wav = await writePcmWav(
      harness.root,
      sampleRate: 16000,
      samples: 3200,
    );
    final recording = await harness.services.recordings.importNativeResult(
      'm-trash',
      NativeRecordingResult(
        path: wav.path,
        duration: const Duration(milliseconds: 200),
        sourceProfile: AudioCaptureProfile.microphoneOnly,
        sha256: 'ab' * 32,
      ),
    );
    await harness.services.meetings.markRecorded('m-trash', recording);
    await harness.services.meetings.moveToTrash('m-trash');
  });

  tearDown(() async {
    await harness.dispose();
  });

  for (final size in const [Size(1080, 720), Size(880, 600)]) {
    final sizeLabel = size.width >= 1000 ? 'extended' : 'narrow';
    for (final brightness in Brightness.values) {
      final mode = brightness == Brightness.dark ? 'dark' : 'light';

      testWidgets('settings $sizeLabel $mode renders without overflow', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          _app(harness, brightness, const SettingsScreen()),
        );
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        if (Platform.environment['EM_GEN_GOLDENS'] == '1') {
          await expectLater(
            find.byType(SettingsScreen),
            matchesGoldenFile('goldens/settings/$sizeLabel-$mode.png'),
          );
        } else {
          expect(tester.takeException(), isNull);
          expect(find.text('设置'), findsWidgets);
          expect(find.text('本地优先与自带 API'), findsOneWidget);
        }
      });

      testWidgets('trash $sizeLabel $mode renders without overflow', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(_app(harness, brightness, const TrashScreen()));
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        if (Platform.environment['EM_GEN_GOLDENS'] == '1') {
          await expectLater(
            find.byType(TrashScreen),
            matchesGoldenFile('goldens/trash/$sizeLabel-$mode.png'),
          );
        } else {
          expect(tester.takeException(), isNull);
          expect(find.text('永久删除'), findsWidgets);
          expect(find.text('恢复'), findsWidgets);
        }
      });
    }
  }
}

Widget _app(TestAppServices harness, Brightness brightness, Widget screen) =>
    ProviderScope(
      overrides: [appServicesProvider.overrideWithValue(harness.services)],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: easyMeetingTheme(Brightness.light),
        darkTheme: easyMeetingTheme(Brightness.dark),
        themeMode: brightness == Brightness.dark
            ? ThemeMode.dark
            : ThemeMode.light,
        home: screen,
      ),
    );
