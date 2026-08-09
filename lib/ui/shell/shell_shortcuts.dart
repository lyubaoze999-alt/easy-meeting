import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/platform_profile.dart';

/// The four fixed desktop navigation destinations in visual order.
///
/// The order is contract-owned: 记录, 会议库, 回收站, 设置. Reordering this enum
/// reorders the desktop rail and the keyboard shortcuts at the same time, so it
/// must never drift from [HomeShell].
enum ShellDestination {
  record,
  library,
  trash,
  settings;

  String get label {
    switch (this) {
      case ShellDestination.record:
        return '记录';
      case ShellDestination.library:
        return '会议库';
      case ShellDestination.trash:
        return '回收站';
      case ShellDestination.settings:
        return '设置';
    }
  }

  IconData get icon {
    switch (this) {
      case ShellDestination.record:
        return Icons.mic_none;
      case ShellDestination.library:
        return Icons.library_books_outlined;
      case ShellDestination.trash:
        return Icons.delete_outline;
      case ShellDestination.settings:
        return Icons.settings_outlined;
    }
  }

  IconData get selectedIcon {
    switch (this) {
      case ShellDestination.record:
        return Icons.mic;
      case ShellDestination.library:
        return Icons.library_books;
      case ShellDestination.trash:
        return Icons.delete;
      case ShellDestination.settings:
        return Icons.settings;
    }
  }

  static ShellDestination fromIndex(int index) {
    switch (index) {
      case 0:
        return ShellDestination.record;
      case 1:
        return ShellDestination.library;
      case 2:
        return ShellDestination.trash;
      case 3:
        return ShellDestination.settings;
    }
    throw ArgumentError.value(
      index,
      'index',
      'Only destinations 0-3 are valid.',
    );
  }
}

/// Intent emitted when a keyboard shortcut selects a shell destination.
class SelectShellDestinationIntent extends Intent {
  const SelectShellDestinationIntent(this.destination);
  final ShellDestination destination;
}

/// The platform-conventional shortcut label for [destination], e.g.
/// `会议库（⌘2）` on macOS and `会议库（Ctrl+2）` on Windows.
///
/// Only the platform convention is surfaced to users even though the bindings
/// themselves accept both Meta and Ctrl for automation and external keyboards.
String shellShortcutLabel(PlatformKind platform, ShellDestination destination) {
  final modifier = platform == PlatformKind.macos ? '⌘' : 'Ctrl+';
  return '${destination.label}（$modifier${destination.index + 1}）';
}

/// Builds the shortcut bindings for all four shell destinations.
///
/// Both Meta and Ctrl modifiers are registered so automation and external
/// keyboards work regardless of the host platform; the visible tooltip only
/// ever shows the platform convention via [shellShortcutLabel]. Plain digit
/// input (no modifier) is intentionally not bound, so text fields keep working.
Map<ShortcutActivator, Intent> shellDestinationShortcuts() {
  final bindings = <ShortcutActivator, Intent>{};
  for (final destination in ShellDestination.values) {
    final key = _digitKey(destination.index);
    bindings[SingleActivator(key, meta: true)] = SelectShellDestinationIntent(
      destination,
    );
    bindings[SingleActivator(key, control: true)] =
        SelectShellDestinationIntent(destination);
  }
  return bindings;
}

LogicalKeyboardKey _digitKey(int index) {
  switch (index) {
    case 0:
      return LogicalKeyboardKey.digit1;
    case 1:
      return LogicalKeyboardKey.digit2;
    case 2:
      return LogicalKeyboardKey.digit3;
    case 3:
      return LogicalKeyboardKey.digit4;
  }
  throw ArgumentError.value(index, 'index', 'Only destinations 0-3 are valid.');
}
