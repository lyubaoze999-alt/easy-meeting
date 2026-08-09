import 'dart:io';

import 'package:audio_capture/audio_capture.dart';
import 'package:easy_meeting/app_services/providers.dart';
import 'package:easy_meeting/domain/models/platform_profile.dart';
import 'package:easy_meeting/ui/onboarding/permission_onboarding_screen.dart';
import 'package:easy_meeting/ui/theme/theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_app_services.dart';

/// Deterministic light/dark visual evidence for the Loop 3 permission
/// onboarding screen at 1080x720. Renders the real Calm Focus
/// [PermissionOnboardingScreen]. Pixel-golden capture is gated behind
/// `EM_GEN_GOLDENS=1`; the default CI path is a deterministic smoke assertion.
///
/// Services are built in `setUp` (the real async zone): TestAppServices.create()
/// performs real file I/O (Directory.systemTemp.createTemp) which does NOT
/// complete inside a testWidgets FakeAsync zone.
void main() {
  late TestAppServices harness;

  setUp(() async {
    harness = await TestAppServices.create();
  });

  tearDown(() async {
    await harness.dispose();
  });

  for (final granted in [true, false]) {
    final state = granted ? 'granted' : 'denied';
    for (final brightness in Brightness.values) {
      final mode = brightness == Brightness.dark ? 'dark' : 'light';
      testWidgets('onboarding $mode $state renders', (tester) async {
        final status = AudioPermissionStatus(
          systemAudioGranted: granted,
          microphoneGranted: granted,
        );
        tester.view.physicalSize = const Size(1080, 720);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appServicesProvider.overrideWithValue(harness.services),
              platformProfileProvider.overrideWithValue(
                const PlatformProfile(
                  platform: PlatformKind.macos,
                  form: DeviceForm.desktop,
                  audio: AudioCapability.dualSource,
                ),
              ),
            ],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: easyMeetingTheme(Brightness.light),
              darkTheme: easyMeetingTheme(Brightness.dark),
              themeMode: brightness == Brightness.dark
                  ? ThemeMode.dark
                  : ThemeMode.light,
              home: PermissionOnboardingScreen(
                capture: AudioCapture(platform: _StubPlatform(status)),
              ),
            ),
          ),
        );
        // Fixed-duration pumps instead of pumpAndSettle: this screen is built on
        // the full TestAppServices (RecordingCoordinator's 250ms ticker drives a
        // continuous animation), so pumpAndSettle would never settle. Matches the
        // loop2_visual_test.dart pattern.
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        if (Platform.environment['EM_GEN_GOLDENS'] == '1') {
          await expectLater(
            find.byType(PermissionOnboardingScreen),
            matchesGoldenFile('goldens/onboarding/$mode-$state.png'),
          );
        } else {
          expect(tester.takeException(), isNull);
          expect(find.byType(PermissionOnboardingScreen), findsOneWidget);
        }
      });
    }
  }
}

class _StubPlatform extends StubAudioCapturePlatform {
  _StubPlatform(this.status);

  final AudioPermissionStatus status;

  @override
  Future<Map<String, Object?>> permissionStatus() async => {
    'systemAudioGranted': status.systemAudioGranted,
    'microphoneGranted': status.microphoneGranted,
  };
}