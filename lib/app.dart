import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_services/providers.dart';
import 'domain/models/configuration.dart';
import 'product_config.dart';
import 'ui/home_shell.dart';
import 'ui/onboarding/permission_onboarding_screen.dart';
import 'ui/theme/theme_tokens.dart';

class EasyMeetingApp extends ConsumerWidget {
  const EasyMeetingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final mode = settings.valueOrNull?.themeMode ?? AppThemeMode.system;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: ProductConfig.displayName,
      theme: easyMeetingTheme(Brightness.light),
      darkTheme: easyMeetingTheme(Brightness.dark),
      themeMode: switch (mode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.system => ThemeMode.system,
      },
      home: settings.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, _) =>
            Scaffold(body: Center(child: Text('无法读取应用设置：$error'))),
        data: (value) => value.onboardingCompleted
            ? const HomeShell()
            : const PermissionOnboardingScreen(),
      ),
    );
  }
}
