import 'package:flutter/material.dart';

import '../theme/theme_tokens.dart';

/// Wraps [child] in a traversal group whose order follows the widget tree.
///
/// Shell navigation uses widget-order traversal so the destination order in the
/// build tree is the exact Tab/Shift+Tab order shown on screen.
class ShellFocusGroup extends StatelessWidget {
  const ShellFocusGroup({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: WidgetOrderTraversalPolicy(),
      child: child,
    );
  }
}

/// Centralized keyboard-focus ring for shell controls.
///
/// Uses the Loop 1 [ThemeTokens.focus] color and
/// [ThemeTokens.focusOutlineWidth] in a constant-width border. Because the
/// border width never changes between focused and unfocused states, toggling
/// focus never causes layout shift; only the border color changes.
BoxDecoration shellFocusRingDecoration({
  required ThemeTokens tokens,
  required bool focused,
  required Color background,
  required BorderRadius borderRadius,
}) {
  return BoxDecoration(
    color: background,
    borderRadius: borderRadius,
    border: Border.all(
      color: focused ? tokens.focus : Colors.transparent,
      width: tokens.focusOutlineWidth,
    ),
  );
}
