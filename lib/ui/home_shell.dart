import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_services/providers.dart';
import '../domain/models/platform_profile.dart';
import 'library/connected_meeting_library_screen.dart';
import 'recording/recording_screen.dart';
import 'settings/settings_screen.dart';
import 'shell/desktop_navigation.dart';
import 'shell/shell_shortcuts.dart';
import 'theme/theme_tokens.dart';
import 'trash/trash_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  /// Creates the shell. [screens] is overridable so widget tests can mount the
  /// real [HomeShell] with lightweight pages instead of the full provider-bound
  /// business screens; production callers use the default [kHomeShellScreens].
  const HomeShell({super.key, this.screens = kHomeShellScreens});

  final List<Widget> screens;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int index = 0;

  // Focus nodes for the desktop rail destinations. Kept on the shell so a
  // keyboard shortcut can move focus to the newly selected destination and
  // never leave it stranded on an IndexedStack page that is no longer visible.
  final List<FocusNode> _destinationFocusNodes = [
    FocusNode(debugLabel: 'shell-destination-record'),
    FocusNode(debugLabel: 'shell-destination-library'),
    FocusNode(debugLabel: 'shell-destination-trash'),
    FocusNode(debugLabel: 'shell-destination-settings'),
  ];

  static const destinations = [
    NavigationDestination(
      icon: Icon(Icons.mic_none),
      selectedIcon: Icon(Icons.mic),
      label: '记录',
    ),
    NavigationDestination(
      icon: Icon(Icons.library_books_outlined),
      label: '会议库',
    ),
    NavigationDestination(icon: Icon(Icons.delete_outline), label: '回收站'),
    NavigationDestination(icon: Icon(Icons.settings_outlined), label: '设置'),
  ];

  @override
  void dispose() {
    for (final node in _destinationFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(platformProfileProvider);
    final screens = widget.screens;
    // A "recent meetings" deep-link on the recording-prep page requests the
    // library tab. Switch to it, then clear the one-shot request after the frame
    // so the library's didUpdateWidget sees the target id before it is reset.
    ref.listen<String?>(selectedMeetingIdProvider, (previous, next) {
      if (next == null) return;
      if (index != 1) _selectDestination(1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(selectedMeetingIdProvider.notifier).state = null;
      });
    });
    if (profile.form == DeviceForm.mobile) {
      return Scaffold(
        body: SafeArea(
          child: IndexedStack(index: index, children: screens),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: _selectDestination,
          destinations: destinations,
        ),
      );
    }
    return _DesktopShell(
      profile: profile,
      selectedIndex: index,
      focusNodes: _destinationFocusNodes,
      onDestinationSelected: _selectDestination,
      body: IndexedStack(index: index, children: screens),
    );
  }

  void _selectDestination(int value) {
    // Re-selecting the current destination is a no-op: no page rebuild and no
    // redundant data reload. The first switch into the library still refreshes.
    if (value == index) {
      return;
    }
    setState(() => index = value);
    if (value == 1) {
      ref.read(meetingLibraryProvider.notifier).load();
    }
  }
}

/// Desktop shell that wires platform digit shortcuts to destination selection
/// and renders the Calm Focus [DesktopNavigation] rail beside the page body.
class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.profile,
    required this.selectedIndex,
    required this.focusNodes,
    required this.onDestinationSelected,
    required this.body,
  });

  final PlatformProfile profile;
  final int selectedIndex;
  final List<FocusNode> focusNodes;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ThemeTokens>()!;
    return Shortcuts(
      shortcuts: shellDestinationShortcuts(),
      child: Actions(
        actions: <Type, Action<Intent>>{
          SelectShellDestinationIntent:
              CallbackAction<SelectShellDestinationIntent>(
                onInvoke: (intent) {
                  final target = intent.destination.index;
                  onDestinationSelected(target);
                  // Move focus onto the visible rail so it never stays on a control
                  // inside the now-hidden IndexedStack page.
                  if (target < focusNodes.length) {
                    focusNodes[target].requestFocus();
                  }
                  return null;
                },
              ),
        },
        child: Focus(
          // Give the shell an initial focus node inside the Shortcuts scope so
          // destination shortcuts work from launch, before the user tabs or
          // clicks into the rail. Placing it here (not on a destination) avoids
          // painting a focus ring over a destination on startup.
          autofocus: true,
          child: Scaffold(
            body: Row(
              children: [
                DesktopNavigation(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  profile: profile,
                  focusNodes: focusNodes,
                  extended: shellIsExtended(MediaQuery.sizeOf(context).width),
                ),
                VerticalDivider(width: 1, thickness: 1, color: tokens.outline),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The real provider-bound business screens mounted by [HomeShell] in
/// production. Kept as a top-level const so the same instances are reused
/// across rebuilds and IndexedStack preserves each page's internal state.
const List<Widget> kHomeShellScreens = [
  RecordingScreen(),
  ConnectedMeetingLibraryScreen(),
  TrashScreen(),
  SettingsScreen(),
];
