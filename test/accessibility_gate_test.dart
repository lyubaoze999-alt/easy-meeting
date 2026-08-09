import 'dart:ui' show Tristate;

import 'package:easy_meeting/domain/models/platform_profile.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:easy_meeting/ui/recording/live_transcript_panel.dart';
import 'package:easy_meeting/ui/shell/desktop_navigation.dart';
import 'package:easy_meeting/ui/theme/theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Loop 8 accessibility gate (R-12): the app must respect the system
/// "reduce motion" setting, be keyboard-navigable with a visible focus ring,
/// expose correct Semantics, and keep primary controls above the WCAG hit-target
/// minimum.
void main() {
  group('reduce motion', () {
    testWidgets(
      'navigation selection animation is disabled under reduce-motion',
      (tester) async {
        final nodes = _focusNodes();
        await tester.pumpWidget(
          _navApp(nodes, extended: true, disableAnimations: true),
        );
        await tester.pumpAndSettle();
        final container = tester.widget<AnimatedContainer>(
          find
              .descendant(
                of: find.byType(DesktopNavigation),
                matching: find.byType(AnimatedContainer),
              )
              .first,
        );
        expect(container.duration, Duration.zero);
        for (final node in nodes) {
          node.dispose();
        }
      },
    );

    testWidgets(
      'navigation selection animates normally when reduce-motion is off',
      (tester) async {
        final nodes = _focusNodes();
        await tester.pumpWidget(
          _navApp(nodes, extended: true, disableAnimations: false),
        );
        await tester.pumpAndSettle();
        final container = tester.widget<AnimatedContainer>(
          find
              .descendant(
                of: find.byType(DesktopNavigation),
                matching: find.byType(AnimatedContainer),
              )
              .first,
        );
        expect(container.duration, const Duration(milliseconds: 120));
        for (final node in nodes) {
          node.dispose();
        }
      },
    );

    testWidgets(
      'live transcript jumps to latest instead of animating under reduce-motion',
      (tester) async {
        Widget panel(int count) => _panelApp(
          List.generate(count, (i) => _line('第$i行', i)),
          disableAnimations: true,
        );
        await tester.pumpWidget(panel(25));
        await tester.pump();
        // Grow the list so the panel auto-scrolls to the newest line.
        await tester.pumpWidget(panel(30));
        await tester.pump(); // post-frame ran _scrollToLatest → jumpTo.
        final scrollable = tester.state<ScrollableState>(
          find.descendant(
            of: find.byType(LiveTranscriptPanel),
            matching: find.byType(Scrollable),
          ),
        );
        // jumpTo is synchronous: no scroll animation is in flight.
        expect(scrollable.position.isScrollingNotifier.value, isFalse);
      },
    );

    testWidgets(
      'live transcript animates to latest when reduce-motion is off',
      (tester) async {
        Widget panel(int count) => _panelApp(
          List.generate(count, (i) => _line('第$i行', i)),
          disableAnimations: false,
        );
        await tester.pumpWidget(panel(25));
        await tester.pump();
        await tester.pumpWidget(panel(30));
        await tester.pump(); // post-frame ran _scrollToLatest → animateTo.
        final scrollable = tester.state<ScrollableState>(
          find.descendant(
            of: find.byType(LiveTranscriptPanel),
            matching: find.byType(Scrollable),
          ),
        );
        // animateTo drives a 180ms scroll animation, so it is still in flight.
        expect(scrollable.position.isScrollingNotifier.value, isTrue);
        await tester.pumpAndSettle();
      },
    );
  });

  group('keyboard order and focus ring', () {
    testWidgets('Tab focuses a nav item and its focus ring becomes visible', (
      tester,
    ) async {
      final nodes = _focusNodes();
      await tester.pumpWidget(_navApp(nodes, extended: true));
      await tester.pumpAndSettle();
      // Focus the first destination and let the AnimatedContainer finish
      // animating its decoration to the focused border.
      nodes[0].requestFocus();
      await tester.pump(const Duration(milliseconds: 150));
      final focused = tester.widget<AnimatedContainer>(
        find
            .descendant(
              of: find.byType(DesktopNavigation),
              matching: find.byType(AnimatedContainer),
            )
            .first,
      );
      final border = focused.decoration as BoxDecoration?;
      expect(border?.border, isNotNull);
      expect((border!.border as Border).top.color, ThemeTokens.light.focus);
      for (final node in nodes) {
        node.dispose();
      }
    });

    testWidgets('focus moves across destinations and Enter activates', (
      tester,
    ) async {
      final nodes = _focusNodes();
      final selected = <int?>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: easyMeetingTheme(Brightness.light),
          home: Scaffold(
            body: Row(
              children: [
                DesktopNavigation(
                  selectedIndex: 0,
                  onDestinationSelected: selected.add,
                  profile: _profile,
                  focusNodes: nodes,
                  extended: true,
                ),
                Expanded(child: Container()),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      nodes[0].requestFocus();
      await tester.pump();
      expect(nodes[0].hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(nodes[1].hasFocus, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(selected.lastOrNull, 1);
      for (final node in nodes) {
        node.dispose();
      }
    });
  });

  group('semantics', () {
    // The destinations live in a separate semantics root, so a single
    // `tester.getSemantics` on the rail is not enough. Each destination's
    // `Semantics` widget maps to a node — but multiple widgets can merge onto
    // one node (the mutually-exclusive group), so dedupe by node id before
    // asserting.
    List<SemanticsNode> destinationNodes(WidgetTester tester) {
      final destinations = find.descendant(
        of: find.byType(DesktopNavigation),
        matching: find.byType(Semantics),
      );
      final unique = <int, SemanticsNode>{};
      for (final element in destinations.evaluate()) {
        final node = tester.getSemantics(find.byWidget(element.widget));
        unique[node.id] = node;
      }
      return unique.values.toList();
    }

    testWidgets('nav destinations expose label, button and selected', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _navApp(_focusNodes(), extended: true, selectedIndex: 2),
      );
      await tester.pumpAndSettle();
      // At least one destination node is a mutually-exclusive-group button
      // with a label.
      final found = destinationNodes(tester).any(
        (node) =>
            node.flagsCollection.isButton &&
            node.flagsCollection.isInMutuallyExclusiveGroup &&
            node.label.isNotEmpty,
      );
      expect(found, isTrue);
      handle.dispose();
    });

    testWidgets('the selected destination reports selected=true', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _navApp(_focusNodes(), extended: true, selectedIndex: 2),
      );
      await tester.pumpAndSettle();
      // The selected destination is index 2, the trash (回收站) item. Prove the
      // node exposed as selected carries that label.
      final selectedTrash = destinationNodes(tester).any(
        (node) =>
            node.flagsCollection.isSelected == Tristate.isTrue &&
            node.label.contains('回收站'),
      );
      expect(selectedTrash, isTrue);
      handle.dispose();
    });
  });

  group('hit targets', () {
    testWidgets('compact rail destinations are at least 44px tall', (
      tester,
    ) async {
      final nodes = _focusNodes();
      await tester.pumpWidget(_navApp(nodes, extended: false));
      await tester.pumpAndSettle();
      final items = find.descendant(
        of: find.byType(DesktopNavigation),
        matching: find.byType(AnimatedContainer),
      );
      for (final element in items.evaluate()) {
        final size = tester.getSize(find.byWidget(element.widget));
        expect(
          size.height,
          greaterThanOrEqualTo(44),
          reason: 'compact nav item must have a ≥44px tap target',
        );
        expect(size.width, greaterThanOrEqualTo(44));
      }
      for (final node in nodes) {
        node.dispose();
      }
    });

    testWidgets('extended rail destinations are at least 44px tall', (
      tester,
    ) async {
      final nodes = _focusNodes();
      await tester.pumpWidget(_navApp(nodes, extended: true));
      await tester.pumpAndSettle();
      final items = find.descendant(
        of: find.byType(DesktopNavigation),
        matching: find.byType(AnimatedContainer),
      );
      for (final element in items.evaluate()) {
        final size = tester.getSize(find.byWidget(element.widget));
        expect(size.height, greaterThanOrEqualTo(44));
      }
      for (final node in nodes) {
        node.dispose();
      }
    });
  });
}

const _profile = PlatformProfile(
  platform: PlatformKind.macos,
  form: DeviceForm.desktop,
  audio: AudioCapability.dualSource,
);

List<FocusNode> _focusNodes() => [
  FocusNode(debugLabel: 'l8-record'),
  FocusNode(debugLabel: 'l8-library'),
  FocusNode(debugLabel: 'l8-trash'),
  FocusNode(debugLabel: 'l8-settings'),
];

Widget _navApp(
  List<FocusNode> nodes, {
  required bool extended,
  bool disableAnimations = false,
  int selectedIndex = 0,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: easyMeetingTheme(Brightness.light),
  home: MediaQuery(
    data: MediaQueryData(
      size: Size(extended ? 1200 : 400, 800),
      disableAnimations: disableAnimations,
    ),
    child: Scaffold(
      body: Row(
        children: [
          DesktopNavigation(
            selectedIndex: selectedIndex,
            onDestinationSelected: (_) {},
            profile: _profile,
            focusNodes: nodes,
            extended: extended,
          ),
          Expanded(child: Container()),
        ],
      ),
    ),
  ),
);

LiveTranscriptLine _line(String text, int index) => LiveTranscriptLine(
  time: Duration(seconds: index),
  text: text,
  isFinal: true,
  itemId: 'line-$index',
);

Widget _panelApp(
  List<LiveTranscriptLine> lines, {
  required bool disableAnimations,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: easyMeetingTheme(Brightness.light),
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(800, 600),
      disableAnimations: disableAnimations,
    ),
    child: Scaffold(
      body: LiveTranscriptPanel(lines: lines, connectionLabel: '已连接'),
    ),
  ),
);
