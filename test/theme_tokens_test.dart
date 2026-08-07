import 'package:easy_meeting/ui/theme/theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Calm Focus light and dark colors match the Loop 1 contract', () {
    expect(ThemeTokens.light.background, const Color(0xFFF6F5EF));
    expect(ThemeTokens.light.surface, Colors.white);
    expect(ThemeTokens.light.surfaceSubtle, const Color(0xFFEFF1EC));
    expect(ThemeTokens.light.primary, const Color(0xFF4F6F5B));
    expect(ThemeTokens.light.primaryHover, const Color(0xFF435F4D));
    expect(ThemeTokens.light.primaryPressed, const Color(0xFF384F41));
    expect(ThemeTokens.light.primaryContainer, const Color(0xFFDDE8DF));
    expect(ThemeTokens.light.onPrimary, Colors.white);
    expect(ThemeTokens.light.textPrimary, const Color(0xFF202721));
    expect(ThemeTokens.light.textSecondary, const Color(0xFF667068));
    expect(ThemeTokens.light.outline, const Color(0xFFD7DDD6));
    expect(ThemeTokens.light.outlineStrong, const Color(0xFFB7C1B9));
    expect(ThemeTokens.light.focus, const Color(0xFF557A65));
    expect(ThemeTokens.light.success, const Color(0xFF3F7654));
    expect(ThemeTokens.light.warning, const Color(0xFFA56B1F));
    expect(ThemeTokens.light.danger, const Color(0xFFC84B44));

    expect(ThemeTokens.dark.background, const Color(0xFF121613));
    expect(ThemeTokens.dark.surface, const Color(0xFF1B211D));
    expect(ThemeTokens.dark.surfaceSubtle, const Color(0xFF222A25));
    expect(ThemeTokens.dark.primary, const Color(0xFF91B29B));
    expect(ThemeTokens.dark.primaryHover, const Color(0xFFA2C1AA));
    expect(ThemeTokens.dark.primaryPressed, const Color(0xFF7DA48A));
    expect(ThemeTokens.dark.primaryContainer, const Color(0xFF2E4436));
    expect(ThemeTokens.dark.onPrimary, const Color(0xFF142018));
    expect(ThemeTokens.dark.textPrimary, const Color(0xFFECF1EC));
    expect(ThemeTokens.dark.textSecondary, const Color(0xFFAAB5AC));
    expect(ThemeTokens.dark.outline, const Color(0xFF39443D));
    expect(ThemeTokens.dark.outlineStrong, const Color(0xFF56635A));
    expect(ThemeTokens.dark.focus, const Color(0xFFA8D0B4));
    expect(ThemeTokens.dark.success, const Color(0xFF92C9A2));
    expect(ThemeTokens.dark.warning, const Color(0xFFF1C27A));
    expect(ThemeTokens.dark.danger, const Color(0xFFFFB4AC));
  });

  test('Calm Focus spacing, radius, and typography values are exact', () {
    final tokens = ThemeTokens.light;

    expect(
      [
        tokens.space4,
        tokens.space8,
        tokens.space12,
        tokens.space16,
        tokens.space20,
        tokens.space24,
        tokens.space32,
        tokens.space40,
        tokens.space48,
      ],
      [4, 8, 12, 16, 20, 24, 32, 40, 48],
    );
    expect(
      [
        tokens.radiusSmall,
        tokens.radiusControl,
        tokens.radiusCard,
        tokens.radiusDialog,
        tokens.radiusPill,
      ],
      [8, 10, 16, 20, 999],
    );
    expect(
      [
        tokens.displayFontSize,
        tokens.displayLineHeight,
        tokens.headlineFontSize,
        tokens.headlineLineHeight,
        tokens.titleFontSize,
        tokens.titleLineHeight,
        tokens.bodyFontSize,
        tokens.bodyLineHeight,
        tokens.labelFontSize,
        tokens.labelLineHeight,
        tokens.captionFontSize,
        tokens.captionLineHeight,
      ],
      [32, 40, 24, 32, 18, 26, 14, 22, 13, 18, 12, 16],
    );
  });

  test('copyWith keeps all token fields and replaces requested fields', () {
    final copy = ThemeTokens.light.copyWith(
      primary: Colors.black,
      space24: 25,
      radiusDialog: 21,
      captionLineHeight: 17,
    );

    expect(copy.primary, Colors.black);
    expect(copy.space24, 25);
    expect(copy.radiusDialog, 21);
    expect(copy.captionLineHeight, 17);
    expect(copy.background, ThemeTokens.light.background);
    expect(copy.surfaceSubtle, ThemeTokens.light.surfaceSubtle);
    expect(copy.danger, ThemeTokens.light.danger);
    expect(copy.space48, ThemeTokens.light.space48);
    expect(copy.radiusPill, ThemeTokens.light.radiusPill);
    expect(copy.displayFontSize, ThemeTokens.light.displayFontSize);
  });

  test('lerp at zero and one preserves both token endpoints', () {
    _expectSame(ThemeTokens.light, ThemeTokens.light.lerp(ThemeTokens.dark, 0));
    _expectSame(ThemeTokens.dark, ThemeTokens.light.lerp(ThemeTokens.dark, 1));
  });

  test('ThemeData derives its component themes from Calm Focus tokens', () {
    for (final brightness in Brightness.values) {
      final theme = easyMeetingTheme(brightness);
      final tokens = brightness == Brightness.dark
          ? ThemeTokens.dark
          : ThemeTokens.light;

      expect(theme.colorScheme.primary, tokens.primary);
      expect(theme.colorScheme.surface, tokens.surface);
      expect(theme.colorScheme.error, tokens.danger);
      expect(theme.scaffoldBackgroundColor, tokens.background);
      expect(theme.textTheme.bodyLarge?.color, tokens.textPrimary);
      expect(theme.cardTheme.color, tokens.surface);
      expect(theme.cardTheme.elevation, 0);
      expect(
        theme.cardTheme.shape,
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusCard),
        ),
      );
      expect(theme.filledButtonTheme.style, isNotNull);
      expect(theme.outlinedButtonTheme.style, isNotNull);
      expect(theme.textButtonTheme.style, isNotNull);
      expect(theme.iconButtonTheme.style, isNotNull);
      expect(theme.inputDecorationTheme.fillColor, tokens.surfaceSubtle);
      expect(theme.navigationRailTheme.indicatorColor, tokens.primaryContainer);
      expect(theme.navigationBarTheme.indicatorColor, tokens.primaryContainer);
      expect(theme.dialogTheme.backgroundColor, tokens.surface);
      expect(theme.dividerTheme.color, tokens.outline);
      expect(theme.chipTheme.selectedColor, tokens.primaryContainer);
      expect(theme.progressIndicatorTheme.color, tokens.primary);
    }
  });

  test('button themes keep minimum width content-sized and height exact', () {
    final theme = easyMeetingTheme(Brightness.light);
    final emptyStates = <WidgetState>{};

    for (final style in [
      theme.filledButtonTheme.style,
      theme.outlinedButtonTheme.style,
      theme.textButtonTheme.style,
    ]) {
      final minimumSize = style?.minimumSize?.resolve(emptyStates);

      expect(minimumSize, isNotNull);
      expect(minimumSize!.width, 0);
      expect(minimumSize.height, 40);
    }
  });
}

void _expectSame(ThemeTokens expected, ThemeTokens actual) {
  expect(actual.background, expected.background);
  expect(actual.surface, expected.surface);
  expect(actual.surfaceSubtle, expected.surfaceSubtle);
  expect(actual.primary, expected.primary);
  expect(actual.primaryHover, expected.primaryHover);
  expect(actual.primaryPressed, expected.primaryPressed);
  expect(actual.primaryContainer, expected.primaryContainer);
  expect(actual.onPrimary, expected.onPrimary);
  expect(actual.textPrimary, expected.textPrimary);
  expect(actual.textSecondary, expected.textSecondary);
  expect(actual.outline, expected.outline);
  expect(actual.outlineStrong, expected.outlineStrong);
  expect(actual.focus, expected.focus);
  expect(actual.success, expected.success);
  expect(actual.warning, expected.warning);
  expect(actual.danger, expected.danger);
  expect(actual.space4, expected.space4);
  expect(actual.space8, expected.space8);
  expect(actual.space12, expected.space12);
  expect(actual.space16, expected.space16);
  expect(actual.space20, expected.space20);
  expect(actual.space24, expected.space24);
  expect(actual.space32, expected.space32);
  expect(actual.space40, expected.space40);
  expect(actual.space48, expected.space48);
  expect(actual.radiusSmall, expected.radiusSmall);
  expect(actual.radiusControl, expected.radiusControl);
  expect(actual.radiusCard, expected.radiusCard);
  expect(actual.radiusDialog, expected.radiusDialog);
  expect(actual.radiusPill, expected.radiusPill);
  expect(actual.displayFontSize, expected.displayFontSize);
  expect(actual.displayLineHeight, expected.displayLineHeight);
  expect(actual.headlineFontSize, expected.headlineFontSize);
  expect(actual.headlineLineHeight, expected.headlineLineHeight);
  expect(actual.titleFontSize, expected.titleFontSize);
  expect(actual.titleLineHeight, expected.titleLineHeight);
  expect(actual.bodyFontSize, expected.bodyFontSize);
  expect(actual.bodyLineHeight, expected.bodyLineHeight);
  expect(actual.labelFontSize, expected.labelFontSize);
  expect(actual.labelLineHeight, expected.labelLineHeight);
  expect(actual.captionFontSize, expected.captionFontSize);
  expect(actual.captionLineHeight, expected.captionLineHeight);
  expect(actual.buttonMinHeight, expected.buttonMinHeight);
  expect(actual.compactButtonHeight, expected.compactButtonHeight);
  expect(actual.focusRingWidth, expected.focusRingWidth);
  expect(actual.focusOutlineWidth, expected.focusOutlineWidth);
}
