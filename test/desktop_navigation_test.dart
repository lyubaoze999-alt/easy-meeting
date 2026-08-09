import 'package:easy_meeting/domain/models/platform_profile.dart';
import 'package:easy_meeting/ui/shell/desktop_navigation.dart';
import 'package:easy_meeting/ui/shell/shell_focus.dart';
import 'package:easy_meeting/ui/theme/theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('breakpoints', () {
    test('1080 is Extended and 1079 is Compact', () {
      expect(shellIsExtended(1079), isFalse);
      expect(shellIsExtended(1080), isTrue);
    });

    test('879, 880 and 1440 resolve to the contract rail widths', () {
      // 879 is below the supported desktop minimum; the function must still be
      // total and treat it as Compact without throwing.
      expect(shellIsExtended(879), isFalse);
      expect(shellRailWidth(879), kShellCompactRailWidth);
      expect(shellIsExtended(880), isFalse);
      expect(shellRailWidth(880), kShellCompactRailWidth);
      expect(shellRailWidth(1079), kShellCompactRailWidth);
      expect(shellIsExtended(1440), isTrue);
      expect(shellRailWidth(1440), kShellExtendedRailWidth);
    });

    test('the breakpoint constants match the contract', () {
      expect(kShellExtendedBreakpoint, 1080);
      expect(kShellCompactRailWidth, 72);
      expect(kShellExtendedRailWidth, 224);
    });
  });

  group('shellFocusRingDecoration', () {
    final tokens = ThemeTokens.light;

    test('uses the focus token and constant width when focused', () {
      final deco = shellFocusRingDecoration(
        tokens: tokens,
        focused: true,
        background: tokens.primaryContainer,
        borderRadius: BorderRadius.circular(tokens.radiusControl),
      );
      final border = deco.border as Border;
      expect(border.top.color, tokens.focus);
      expect(border.top.width, tokens.focusOutlineWidth);
    });

    test('keeps the same width unfocused so focus never shifts layout', () {
      final focused = shellFocusRingDecoration(
        tokens: tokens,
        focused: true,
        background: const Color(0x00000000),
        borderRadius: BorderRadius.zero,
      );
      final unfocused = shellFocusRingDecoration(
        tokens: tokens,
        focused: false,
        background: const Color(0x00000000),
        borderRadius: BorderRadius.zero,
      );
      final focusedBorder = focused.border as Border;
      final unfocusedBorder = unfocused.border as Border;
      expect(focusedBorder.top.width, unfocusedBorder.top.width);
      expect(unfocusedBorder.top.color, Colors.transparent);
    });
  });

  group('DesktopNavigation rendering', () {
    testWidgets('Compact rail is 72 wide and hides labels', (tester) async {
      final harness = await _pumpNavigation(
        tester,
        profile: _macosProfile,
        extended: false,
      );
      expect(tester.getSize(find.byType(DesktopNavigation)).width, 72);
      // Destination labels are not rendered as Text in Compact mode.
      expect(find.text('会议库'), findsNothing);
      expect(find.text('会议纪要'), findsNothing);
      // Four destination icons plus the brand icon are present. The record
      // destination is selected (index 0), so it renders its filled mic icon.
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.library_books_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
      expect(find.byIcon(Icons.graphic_eq), findsOneWidget);
      harness.dispose();
    });

    testWidgets('Extended rail is 224 wide and shows Chinese labels', (
      tester,
    ) async {
      final harness = await _pumpNavigation(
        tester,
        profile: _windowsProfile,
        extended: true,
      );
      expect(tester.getSize(find.byType(DesktopNavigation)).width, 224);
      expect(find.text('记录'), findsOneWidget);
      expect(find.text('会议库'), findsOneWidget);
      expect(find.text('回收站'), findsOneWidget);
      expect(find.text('设置'), findsOneWidget);
      expect(find.text('会议纪要'), findsOneWidget);
      harness.dispose();
    });

    testWidgets('rail background derives from the light surface token', (
      tester,
    ) async {
      await _expectRailSurface(tester, Brightness.light);
    });

    testWidgets('rail background derives from the dark surface token', (
      tester,
    ) async {
      await _expectRailSurface(tester, Brightness.dark);
    });
  });

  group('DesktopNavigation selection', () {
    testWidgets('clicking each destination reports its index', (tester) async {
      final harness = await _pumpNavigation(
        tester,
        profile: _macosProfile,
        extended: true,
      );
      await tester.tap(find.text('会议库'));
      expect(harness.selected, 1);
      await tester.tap(find.text('回收站'));
      expect(harness.selected, 2);
      await tester.tap(find.text('设置'));
      expect(harness.selected, 3);
      await tester.tap(find.text('记录'));
      expect(harness.selected, 0);
      harness.dispose();
    });

    testWidgets('tooltips surface the platform shortcut', (tester) async {
      await _pumpNavigation(tester, profile: _macosProfile, extended: false);
      expect(find.byTooltip('会议库（⌘2）'), findsOneWidget);
      expect(find.byTooltip('设置（⌘4）'), findsOneWidget);
    });

    testWidgets('Windows tooltips show Ctrl, not ⌘', (tester) async {
      await _pumpNavigation(tester, profile: _windowsProfile, extended: false);
      expect(find.byTooltip('会议库（Ctrl+2）'), findsOneWidget);
      expect(find.byTooltip('设置（Ctrl+4）'), findsOneWidget);
    });
  });

  group('DesktopNavigation keyboard', () {
    testWidgets('arrow down moves focus and Enter activates', (tester) async {
      final harness = await _pumpNavigation(
        tester,
        profile: _macosProfile,
        extended: true,
      );
      harness.nodes[0].requestFocus();
      await tester.pump();
      expect(harness.nodes[0].hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(harness.nodes[1].hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(harness.selected, 1);
      harness.dispose();
    });

    testWidgets('arrow up moves focus backwards', (tester) async {
      final harness = await _pumpNavigation(
        tester,
        profile: _macosProfile,
        extended: true,
        selectedIndex: 2,
      );
      harness.nodes[2].requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(harness.nodes[1].hasFocus, isTrue);
      harness.dispose();
    });

    testWidgets('Space activates the focused destination', (tester) async {
      final harness = await _pumpNavigation(
        tester,
        profile: _macosProfile,
        extended: true,
      );
      harness.nodes[3].requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(harness.selected, 3);
      harness.dispose();
    });

    testWidgets('arrow down clamps at the last destination', (tester) async {
      final harness = await _pumpNavigation(
        tester,
        profile: _macosProfile,
        extended: true,
        selectedIndex: 3,
      );
      harness.nodes[3].requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(harness.nodes[3].hasFocus, isTrue);
      harness.dispose();
    });
  });

  group('DesktopNavigation semantics', () {
    testWidgets('exposes the selected destination via its filled icon', (
      tester,
    ) async {
      await _pumpNavigation(
        tester,
        profile: _macosProfile,
        extended: true,
        selectedIndex: 1,
      );
      // The selected library destination swaps the outlined icon for the
      // filled one, so selection is never conveyed by color alone.
      expect(find.byIcon(Icons.library_books), findsOneWidget);
      expect(find.byIcon(Icons.library_books_outlined), findsNothing);
    });

    testWidgets('the decorative brand icon is excluded from semantics', (
      tester,
    ) async {
      await _pumpNavigation(tester, profile: _macosProfile, extended: true);
      expect(
        find.ancestor(
          of: find.byIcon(Icons.graphic_eq),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    });
  });
}

/// Pumps the [DesktopNavigation] in one fixed brightness and asserts its root
/// [Material] uses the matching [ThemeTokens.surface]. Kept as a single-pump
/// helper: re-pumping a different brightness inside one testWidgets does not
/// reliably swap `Theme.of(context).extension`, so each brightness gets its own
/// test.
Future<void> _expectRailSurface(
  WidgetTester tester,
  Brightness brightness,
) async {
  final tokens = brightness == Brightness.dark
      ? ThemeTokens.dark
      : ThemeTokens.light;
  final harness = await _pumpNavigation(
    tester,
    profile: _macosProfile,
    extended: true,
    brightness: brightness,
  );
  addTearDown(harness.dispose);
  final material = tester.widget<Material>(
    find
        .descendant(
          of: find.byType(DesktopNavigation),
          matching: find.byType(Material),
        )
        .first,
  );
  expect(material.color, tokens.surface);
}

const _macosProfile = PlatformProfile(
  platform: PlatformKind.macos,
  form: DeviceForm.desktop,
  audio: AudioCapability.dualSource,
);

const _windowsProfile = PlatformProfile(
  platform: PlatformKind.windows,
  form: DeviceForm.desktop,
  audio: AudioCapability.dualSource,
);

class _NavHarness {
  _NavHarness(this.nodes, this.selecteds);
  final List<FocusNode> nodes;
  final List<int?> selecteds;
  int? get selected => selecteds.lastOrNull;
  void dispose() {
    for (final node in nodes) {
      node.dispose();
    }
  }
}

Future<_NavHarness> _pumpNavigation(
  WidgetTester tester, {
  required PlatformProfile profile,
  int selectedIndex = 0,
  required bool extended,
  Brightness brightness = Brightness.light,
}) async {
  final nodes = [
    FocusNode(debugLabel: 'test-record'),
    FocusNode(debugLabel: 'test-library'),
    FocusNode(debugLabel: 'test-trash'),
    FocusNode(debugLabel: 'test-settings'),
  ];
  final selecteds = <int?>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: easyMeetingTheme(brightness),
      home: Scaffold(
        body: Row(
          children: [
            DesktopNavigation(
              selectedIndex: selectedIndex,
              onDestinationSelected: selecteds.add,
              profile: profile,
              focusNodes: nodes,
              extended: extended,
            ),
            Expanded(child: Container()),
          ],
        ),
      ),
    ),
  );
  // Settle layout and any theme change so the surface token on the nav rail
  // reflects the pumped brightness (re-pumping with a new theme otherwise leaks
  // stale inherited state across loop iterations).
  await tester.pumpAndSettle();
  return _NavHarness(nodes, selecteds);
}
