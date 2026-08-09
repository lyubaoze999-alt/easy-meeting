import 'package:easy_meeting/domain/models/platform_profile.dart';
import 'package:easy_meeting/ui/shell/shell_shortcuts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shellShortcutLabel', () {
    test('uses ⌘ and the destination number on macOS', () {
      expect(
        shellShortcutLabel(PlatformKind.macos, ShellDestination.record),
        '记录（⌘1）',
      );
      expect(
        shellShortcutLabel(PlatformKind.macos, ShellDestination.library),
        '会议库（⌘2）',
      );
      expect(
        shellShortcutLabel(PlatformKind.macos, ShellDestination.trash),
        '回收站（⌘3）',
      );
      expect(
        shellShortcutLabel(PlatformKind.macos, ShellDestination.settings),
        '设置（⌘4）',
      );
    });

    test('uses Ctrl+ and the destination number on Windows', () {
      expect(
        shellShortcutLabel(PlatformKind.windows, ShellDestination.library),
        '会议库（Ctrl+2）',
      );
      expect(
        shellShortcutLabel(PlatformKind.windows, ShellDestination.settings),
        '设置（Ctrl+4）',
      );
    });

    test('never shows the wrong platform modifier', () {
      for (final destination in ShellDestination.values) {
        final mac = shellShortcutLabel(PlatformKind.macos, destination);
        final win = shellShortcutLabel(PlatformKind.windows, destination);
        expect(mac.contains('Ctrl'), isFalse);
        expect(win.contains('⌘'), isFalse);
      }
    });
  });

  group('ShellDestination', () {
    test('declaration order matches the contract indices 0-3', () {
      expect(ShellDestination.record.index, 0);
      expect(ShellDestination.library.index, 1);
      expect(ShellDestination.trash.index, 2);
      expect(ShellDestination.settings.index, 3);
    });

    test('fromIndex round-trips every destination', () {
      for (final destination in ShellDestination.values) {
        expect(ShellDestination.fromIndex(destination.index), destination);
      }
    });

    test('fromIndex rejects out-of-range indices', () {
      expect(() => ShellDestination.fromIndex(4), throwsArgumentError);
      expect(() => ShellDestination.fromIndex(-1), throwsArgumentError);
    });

    test('every destination has a distinct filled selected icon', () {
      final icons = ShellDestination.values.map((d) => d.selectedIcon).toSet();
      expect(icons.length, ShellDestination.values.length);
    });
  });

  group('shellDestinationShortcuts', () {
    // SingleActivator uses identity equality in this Flutter version, so the
    // bindings map is compared by value (trigger + modifiers), not by `==`.
    bool isBinding(
      MapEntry<ShortcutActivator, Intent> entry,
      LogicalKeyboardKey trigger, {
      bool meta = false,
      bool control = false,
    }) {
      final key = entry.key;
      return key is SingleActivator &&
          key.trigger == trigger &&
          key.meta == meta &&
          key.control == control &&
          !key.shift &&
          !key.alt;
    }

    test('binds both Meta and Ctrl for every destination', () {
      final bindings = shellDestinationShortcuts();

      for (final destination in ShellDestination.values) {
        final trigger = _digitKey(destination.index);
        final metaEntry = bindings.entries.firstWhere(
          (entry) => isBinding(entry, trigger, meta: true),
        );
        final ctrlEntry = bindings.entries.firstWhere(
          (entry) => isBinding(entry, trigger, control: true),
        );
        expect(
          metaEntry.value,
          isA<SelectShellDestinationIntent>().having(
            (i) => i.destination,
            'destination',
            destination,
          ),
        );
        expect(
          ctrlEntry.value,
          isA<SelectShellDestinationIntent>().having(
            (i) => i.destination,
            'destination',
            destination,
          ),
        );
      }
    });

    test('does not bind plain digit input without a modifier', () {
      final bindings = shellDestinationShortcuts();
      for (final destination in ShellDestination.values) {
        final trigger = _digitKey(destination.index);
        final plain = bindings.entries.where(
          (entry) => isBinding(entry, trigger),
        );
        expect(
          plain,
          isEmpty,
          reason: 'Plain digits must reach text fields, not the shell.',
        );
      }
    });
  });
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
