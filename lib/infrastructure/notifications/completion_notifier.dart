import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

abstract interface class CompletionNotifier {
  Future<bool> requestPermission();
  Future<void> processingCompleted(String title);
}

class NoopCompletionNotifier implements CompletionNotifier {
  const NoopCompletionNotifier();

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> processingCompleted(String title) async {}
}

class LocalCompletionNotifier implements CompletionNotifier {
  LocalCompletionNotifier(this.plugin);

  final FlutterLocalNotificationsPlugin plugin;

  static Future<LocalCompletionNotifier> open() async {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        windows: WindowsInitializationSettings(
          appName: '会议纪要',
          appUserModelId: 'com.meetingnotes.app',
          guid: '623daaf0-7af1-4c56-9e48-2ba342b0b9cb',
        ),
      ),
    );
    return LocalCompletionNotifier(plugin);
  }

  @override
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      return await plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    if (Platform.isIOS) {
      return await plugin
              .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: false, sound: true) ??
          false;
    }
    if (Platform.isMacOS) {
      return await plugin
              .resolvePlatformSpecificImplementation<
                MacOSFlutterLocalNotificationsPlugin
              >()
              ?.requestPermissions(alert: true, badge: false, sound: true) ??
          false;
    }
    return true;
  }

  @override
  Future<void> processingCompleted(String title) => plugin.show(
    id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
    title: '纪要已生成',
    body: title,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'processing_completed',
        '纪要处理完成',
        channelDescription: '会议转写和总结完成时通知',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
      windows: WindowsNotificationDetails(),
    ),
  );
}
