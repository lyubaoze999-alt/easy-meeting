import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_services/providers.dart';
import '../domain/models/platform_profile.dart';
import 'library/notes_library_screen.dart';
import 'recording/recording_screen.dart';
import 'settings/settings_screen.dart';
import 'trash/trash_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int index = 0;

  static const destinations = [
    NavigationDestination(
      icon: Icon(Icons.mic_none),
      selectedIcon: Icon(Icons.mic),
      label: '记录',
    ),
    NavigationDestination(
      icon: Icon(Icons.library_books_outlined),
      label: '纪要库',
    ),
    NavigationDestination(icon: Icon(Icons.delete_outline), label: '回收站'),
    NavigationDestination(icon: Icon(Icons.settings_outlined), label: '设置'),
  ];

  static const screens = [
    RecordingScreen(),
    NotesLibraryScreen(),
    TrashScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(platformProfileProvider);
    if (profile.form == DeviceForm.mobile) {
      return Scaffold(
        body: SafeArea(
          child: IndexedStack(index: index, children: screens),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (value) => setState(() => index = value),
          destinations: destinations,
        ),
      );
    }
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.sizeOf(context).width >= 1080,
            selectedIndex: index,
            onDestinationSelected: (value) => setState(() => index = value),
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Icon(Icons.graphic_eq, size: 32),
            ),
            destinations: destinations
                .map(
                  (item) => NavigationRailDestination(
                    icon: item.icon,
                    selectedIcon: item.selectedIcon,
                    label: Text(item.label),
                  ),
                )
                .toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(index: index, children: screens),
          ),
        ],
      ),
    );
  }
}
