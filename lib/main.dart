import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'app_services/app_services.dart';
import 'app_services/providers.dart';
import 'desktop/desktop_tray_controller.dart';
import 'product_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isMacOS || Platform.isWindows) {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(1080, 720),
        minimumSize: Size(880, 600),
        center: true,
        title: ProductConfig.displayName,
      ),
      () async => windowManager.show(),
    );
  }
  final services = await AppServices.create();
  runApp(
    ProviderScope(
      overrides: [appServicesProvider.overrideWithValue(services)],
      child: const EasyMeetingApp(),
    ),
  );
  unawaited(services.session.initialize());
  if (Platform.isMacOS || Platform.isWindows) {
    unawaited(DesktopTrayController(services).init());
  }
}
