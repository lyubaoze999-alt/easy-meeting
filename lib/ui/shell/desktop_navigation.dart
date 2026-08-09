import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/platform_profile.dart';
import '../../product_config.dart';
import '../theme/theme_tokens.dart';
import 'shell_focus.dart';
import 'shell_shortcuts.dart';

/// The viewport width at which the desktop rail switches from Compact to
/// Extended. `1080` is Extended; `1079` is Compact. This is the single source
/// of truth for the breakpoint — the widget tree must not re-hardcode it.
const double kShellExtendedBreakpoint = 1080;

/// Compact rail width (icon-only) and Extended rail width (icon + label).
const double kShellCompactRailWidth = 72;
const double kShellExtendedRailWidth = 224;

/// Returns true when [viewportWidth] should render the Extended rail.
bool shellIsExtended(double viewportWidth) =>
    viewportWidth >= kShellExtendedBreakpoint;

/// Returns the rail width for [viewportWidth].
double shellRailWidth(double viewportWidth) => shellIsExtended(viewportWidth)
    ? kShellExtendedRailWidth
    : kShellCompactRailWidth;

/// A Calm Focus desktop navigation rail.
///
/// Renders the four fixed [ShellDestination] entries with Hover, Pressed,
/// Selected, Keyboard Focus and Disabled states drawn entirely from
/// [ThemeTokens]. Mouse clicks and keyboard activation both call
/// [onDestinationSelected], so the two input paths can never diverge.
class DesktopNavigation extends StatelessWidget {
  const DesktopNavigation({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.profile,
    required this.focusNodes,
    required this.extended,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final PlatformProfile profile;
  final List<FocusNode> focusNodes;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ThemeTokens>()!;
    return Material(
      color: tokens.surface,
      child: SizedBox(
        width: extended ? kShellExtendedRailWidth : kShellCompactRailWidth,
        child: SafeArea(
          child: ShellFocusGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DesktopBrandHeader(extended: extended),
                Expanded(
                  child: Shortcuts(
                    shortcuts: const {
                      SingleActivator(LogicalKeyboardKey.arrowDown):
                          _NextDestinationIntent(),
                      SingleActivator(LogicalKeyboardKey.arrowUp):
                          _PreviousDestinationIntent(),
                    },
                    child: Actions(
                      actions: <Type, Action<Intent>>{
                        _NextDestinationIntent:
                            CallbackAction<_NextDestinationIntent>(
                              onInvoke: (_) => _moveFocus(1),
                            ),
                        _PreviousDestinationIntent:
                            CallbackAction<_PreviousDestinationIntent>(
                              onInvoke: (_) => _moveFocus(-1),
                            ),
                      },
                      child: Shortcuts(
                        shortcuts: const {
                          SingleActivator(LogicalKeyboardKey.enter):
                              _ActivateDestinationIntent(),
                          SingleActivator(LogicalKeyboardKey.space):
                              _ActivateDestinationIntent(),
                        },
                        child: Actions(
                          actions: <Type, Action<Intent>>{
                            _ActivateDestinationIntent:
                                CallbackAction<_ActivateDestinationIntent>(
                                  onInvoke: (_) {
                                    _activateFocused();
                                    return null;
                                  },
                                ),
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (
                                var i = 0;
                                i < ShellDestination.values.length;
                                i++
                              )
                                _DesktopNavDestination(
                                  key: ValueKey(ShellDestination.fromIndex(i)),
                                  destination: ShellDestination.fromIndex(i),
                                  selected: i == selectedIndex,
                                  extended: extended,
                                  profile: profile,
                                  focusNode: focusNodes[i],
                                  onSelected: () => onDestinationSelected(i),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _moveFocus(int delta) {
    final current = focusNodes.indexWhere((node) => node.hasFocus);
    final start = current == -1 ? selectedIndex : current;
    var next = (start + delta).clamp(0, focusNodes.length - 1);
    focusNodes[next].requestFocus();
  }

  // Enter/Space activate whichever destination currently has focus. The
  // activation Shortcuts/Actions live above the destination Focus nodes (so
  // they are ancestors of the focused widget), and this translates the focused
  // node back to its destination index.
  void _activateFocused() {
    final focused = focusNodes.indexWhere((node) => node.hasFocus);
    if (focused == -1) return;
    onDestinationSelected(focused);
  }
}

class _DesktopBrandHeader extends StatelessWidget {
  const _DesktopBrandHeader({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ThemeTokens>()!;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.space16,
        tokens.space20,
        tokens.space16,
        tokens.space16,
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Icon(Icons.graphic_eq, size: 28, color: tokens.primary),
          ),
          if (extended) ...[
            SizedBox(width: tokens.space12),
            Expanded(
              child: Text(
                ProductConfig.displayName,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: tokens.titleFontSize,
                  fontWeight: FontWeight.w600,
                  height: tokens.titleLineHeight / tokens.titleFontSize,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DesktopNavDestination extends StatefulWidget {
  const _DesktopNavDestination({
    super.key,
    required this.destination,
    required this.selected,
    required this.extended,
    required this.profile,
    required this.focusNode,
    required this.onSelected,
  });

  final ShellDestination destination;
  final bool selected;
  final bool extended;
  final PlatformProfile profile;
  final FocusNode focusNode;
  final VoidCallback onSelected;

  @override
  State<_DesktopNavDestination> createState() => _DesktopNavDestinationState();
}

class _DesktopNavDestinationState extends State<_DesktopNavDestination> {
  bool _hovered = false;
  bool _pressed = false;

  Color get _background {
    final tokens = Theme.of(context).extension<ThemeTokens>()!;
    if (widget.selected) return tokens.primaryContainer;
    if (_pressed) return tokens.primary.withValues(alpha: .12);
    if (_hovered) return tokens.primary.withValues(alpha: .08);
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<ThemeTokens>()!;
    final destination = widget.destination;
    final selected = widget.selected;
    final icon = selected ? destination.selectedIcon : destination.icon;
    final iconColor = selected ? tokens.primary : tokens.textSecondary;
    final labelColor = selected ? tokens.primary : tokens.textPrimary;
    final radius = BorderRadius.circular(tokens.radiusControl);
    final tooltip = shellShortcutLabel(widget.profile.platform, destination);

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: Focus(
        focusNode: widget.focusNode,
        child: ListenableBuilder(
          listenable: widget.focusNode,
          builder: (context, _) {
            final hasFocus = widget.focusNode.hasFocus;
            return MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => setState(() => _pressed = true),
                onTapUp: (_) => setState(() => _pressed = false),
                onTapCancel: () => setState(() => _pressed = false),
                onTap: () {
                  // Focus follows click so the rail is keyboard-ready after a
                  // mouse interaction.
                  widget.focusNode.requestFocus();
                  widget.onSelected();
                },
                child: Semantics(
                  label: destination.label,
                  button: true,
                  selected: selected,
                  inMutuallyExclusiveGroup: true,
                  child: AnimatedContainer(
                    // Respect the system "reduce motion" accessibility
                    // setting: when animations are disabled the selection
                    // state switches instantly instead of animating.
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    constraints: BoxConstraints(
                      // WCAG 2.5.5: the compact rail item is padded to the same
                      // 48px minimum as the extended item so the tap target is
                      // ≥48px in both modes.
                      minHeight: 48,
                      minWidth: 40,
                    ),
                    margin: EdgeInsets.symmetric(
                      horizontal: widget.extended
                          ? tokens.space8
                          : tokens.space4,
                      vertical: tokens.space4,
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.extended ? tokens.space12 : 0,
                      vertical: tokens.space8,
                    ),
                    decoration: shellFocusRingDecoration(
                      tokens: tokens,
                      focused: hasFocus,
                      background: _background,
                      borderRadius: radius,
                    ),
                    child: widget.extended
                        ? Row(
                            children: [
                              Icon(icon, color: iconColor, size: 22),
                              SizedBox(width: tokens.space12),
                              Expanded(
                                child: Text(
                                  destination.label,
                                  style: TextStyle(
                                    color: labelColor,
                                    fontSize: tokens.labelFontSize,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    height:
                                        tokens.labelLineHeight /
                                        tokens.labelFontSize,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        : Center(child: Icon(icon, color: iconColor, size: 22)),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NextDestinationIntent extends Intent {
  const _NextDestinationIntent();
}

class _PreviousDestinationIntent extends Intent {
  const _PreviousDestinationIntent();
}

class _ActivateDestinationIntent extends Intent {
  const _ActivateDestinationIntent();
}
