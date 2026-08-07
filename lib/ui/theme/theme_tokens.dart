import 'package:flutter/material.dart';

/// The single source of truth for the Calm Focus visual language.
///
/// Values in this extension intentionally mirror the Loop 1 contract. Keep
/// component themes below derived from these values so a light/dark change
/// cannot leave behind a one-off Material color.
@immutable
class ThemeTokens extends ThemeExtension<ThemeTokens> {
  const ThemeTokens({
    required this.background,
    required this.surface,
    required this.surfaceSubtle,
    required this.primary,
    required this.primaryHover,
    required this.primaryPressed,
    required this.primaryContainer,
    required this.onPrimary,
    required this.textPrimary,
    required this.textSecondary,
    required this.outline,
    required this.outlineStrong,
    required this.focus,
    required this.success,
    required this.warning,
    required this.danger,
    this.space4 = 4,
    this.space8 = 8,
    this.space12 = 12,
    this.space16 = 16,
    this.space20 = 20,
    this.space24 = 24,
    this.space32 = 32,
    this.space40 = 40,
    this.space48 = 48,
    this.radiusSmall = 8,
    this.radiusControl = 10,
    this.radiusCard = 16,
    this.radiusDialog = 20,
    this.radiusPill = 999,
    this.displayFontSize = 32,
    this.displayLineHeight = 40,
    this.headlineFontSize = 24,
    this.headlineLineHeight = 32,
    this.titleFontSize = 18,
    this.titleLineHeight = 26,
    this.bodyFontSize = 14,
    this.bodyLineHeight = 22,
    this.labelFontSize = 13,
    this.labelLineHeight = 18,
    this.captionFontSize = 12,
    this.captionLineHeight = 16,
    this.buttonMinHeight = 40,
    this.compactButtonHeight = 32,
    this.focusRingWidth = 2,
    this.focusOutlineWidth = 2,
  });

  final Color background;
  final Color surface;
  final Color surfaceSubtle;
  final Color primary;
  final Color primaryHover;
  final Color primaryPressed;
  final Color primaryContainer;
  final Color onPrimary;
  final Color textPrimary;
  final Color textSecondary;
  final Color outline;
  final Color outlineStrong;
  final Color focus;
  final Color success;
  final Color warning;
  final Color danger;

  final double space4;
  final double space8;
  final double space12;
  final double space16;
  final double space20;
  final double space24;
  final double space32;
  final double space40;
  final double space48;

  final double radiusSmall;
  final double radiusControl;
  final double radiusCard;
  final double radiusDialog;
  final double radiusPill;

  final double displayFontSize;
  final double displayLineHeight;
  final double headlineFontSize;
  final double headlineLineHeight;
  final double titleFontSize;
  final double titleLineHeight;
  final double bodyFontSize;
  final double bodyLineHeight;
  final double labelFontSize;
  final double labelLineHeight;
  final double captionFontSize;
  final double captionLineHeight;

  final double buttonMinHeight;
  final double compactButtonHeight;
  final double focusRingWidth;
  final double focusOutlineWidth;

  // Compatibility aliases for existing callers; both remain contract-owned.
  Color get accentPrimary => primary;
  Color get accentSecondary => primaryContainer;
  Color get recording => danger;
  double get cornerRadius => radiusCard;
  double get spacingUnit => space8;

  static const light = ThemeTokens(
    background: Color(0xFFF6F5EF),
    surface: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFEFF1EC),
    primary: Color(0xFF4F6F5B),
    primaryHover: Color(0xFF435F4D),
    primaryPressed: Color(0xFF384F41),
    primaryContainer: Color(0xFFDDE8DF),
    onPrimary: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF202721),
    textSecondary: Color(0xFF667068),
    outline: Color(0xFFD7DDD6),
    outlineStrong: Color(0xFFB7C1B9),
    focus: Color(0xFF557A65),
    success: Color(0xFF3F7654),
    warning: Color(0xFFA56B1F),
    danger: Color(0xFFC84B44),
  );

  static const dark = ThemeTokens(
    background: Color(0xFF121613),
    surface: Color(0xFF1B211D),
    surfaceSubtle: Color(0xFF222A25),
    primary: Color(0xFF91B29B),
    primaryHover: Color(0xFFA2C1AA),
    primaryPressed: Color(0xFF7DA48A),
    primaryContainer: Color(0xFF2E4436),
    onPrimary: Color(0xFF142018),
    textPrimary: Color(0xFFECF1EC),
    textSecondary: Color(0xFFAAB5AC),
    outline: Color(0xFF39443D),
    outlineStrong: Color(0xFF56635A),
    focus: Color(0xFFA8D0B4),
    success: Color(0xFF92C9A2),
    warning: Color(0xFFF1C27A),
    danger: Color(0xFFFFB4AC),
  );

  @override
  ThemeTokens copyWith({
    Color? background,
    Color? surface,
    Color? surfaceSubtle,
    Color? primary,
    Color? primaryHover,
    Color? primaryPressed,
    Color? primaryContainer,
    Color? onPrimary,
    Color? textPrimary,
    Color? textSecondary,
    Color? outline,
    Color? outlineStrong,
    Color? focus,
    Color? success,
    Color? warning,
    Color? danger,
    double? space4,
    double? space8,
    double? space12,
    double? space16,
    double? space20,
    double? space24,
    double? space32,
    double? space40,
    double? space48,
    double? radiusSmall,
    double? radiusControl,
    double? radiusCard,
    double? radiusDialog,
    double? radiusPill,
    double? displayFontSize,
    double? displayLineHeight,
    double? headlineFontSize,
    double? headlineLineHeight,
    double? titleFontSize,
    double? titleLineHeight,
    double? bodyFontSize,
    double? bodyLineHeight,
    double? labelFontSize,
    double? labelLineHeight,
    double? captionFontSize,
    double? captionLineHeight,
    double? buttonMinHeight,
    double? compactButtonHeight,
    double? focusRingWidth,
    double? focusOutlineWidth,
    // Kept for source compatibility with the Loop 0 token shape.
    double? cornerRadius,
    double? spacingUnit,
  }) => ThemeTokens(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    surfaceSubtle: surfaceSubtle ?? this.surfaceSubtle,
    primary: primary ?? this.primary,
    primaryHover: primaryHover ?? this.primaryHover,
    primaryPressed: primaryPressed ?? this.primaryPressed,
    primaryContainer: primaryContainer ?? this.primaryContainer,
    onPrimary: onPrimary ?? this.onPrimary,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    outline: outline ?? this.outline,
    outlineStrong: outlineStrong ?? this.outlineStrong,
    focus: focus ?? this.focus,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    space4: space4 ?? this.space4,
    space8: spacingUnit ?? space8 ?? this.space8,
    space12: space12 ?? this.space12,
    space16: space16 ?? this.space16,
    space20: space20 ?? this.space20,
    space24: space24 ?? this.space24,
    space32: space32 ?? this.space32,
    space40: space40 ?? this.space40,
    space48: space48 ?? this.space48,
    radiusSmall: radiusSmall ?? this.radiusSmall,
    radiusControl: radiusControl ?? this.radiusControl,
    radiusCard: cornerRadius ?? radiusCard ?? this.radiusCard,
    radiusDialog: radiusDialog ?? this.radiusDialog,
    radiusPill: radiusPill ?? this.radiusPill,
    displayFontSize: displayFontSize ?? this.displayFontSize,
    displayLineHeight: displayLineHeight ?? this.displayLineHeight,
    headlineFontSize: headlineFontSize ?? this.headlineFontSize,
    headlineLineHeight: headlineLineHeight ?? this.headlineLineHeight,
    titleFontSize: titleFontSize ?? this.titleFontSize,
    titleLineHeight: titleLineHeight ?? this.titleLineHeight,
    bodyFontSize: bodyFontSize ?? this.bodyFontSize,
    bodyLineHeight: bodyLineHeight ?? this.bodyLineHeight,
    labelFontSize: labelFontSize ?? this.labelFontSize,
    labelLineHeight: labelLineHeight ?? this.labelLineHeight,
    captionFontSize: captionFontSize ?? this.captionFontSize,
    captionLineHeight: captionLineHeight ?? this.captionLineHeight,
    buttonMinHeight: buttonMinHeight ?? this.buttonMinHeight,
    compactButtonHeight: compactButtonHeight ?? this.compactButtonHeight,
    focusRingWidth: focusRingWidth ?? this.focusRingWidth,
    focusOutlineWidth: focusOutlineWidth ?? this.focusOutlineWidth,
  );

  @override
  ThemeTokens lerp(covariant ThemeTokens? other, double t) {
    if (other == null) return this;
    double lerpDouble(double a, double b) => a + (b - a) * t;
    return ThemeTokens(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryHover: Color.lerp(primaryHover, other.primaryHover, t)!,
      primaryPressed: Color.lerp(primaryPressed, other.primaryPressed, t)!,
      primaryContainer: Color.lerp(
        primaryContainer,
        other.primaryContainer,
        t,
      )!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      outlineStrong: Color.lerp(outlineStrong, other.outlineStrong, t)!,
      focus: Color.lerp(focus, other.focus, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      space4: lerpDouble(space4, other.space4),
      space8: lerpDouble(space8, other.space8),
      space12: lerpDouble(space12, other.space12),
      space16: lerpDouble(space16, other.space16),
      space20: lerpDouble(space20, other.space20),
      space24: lerpDouble(space24, other.space24),
      space32: lerpDouble(space32, other.space32),
      space40: lerpDouble(space40, other.space40),
      space48: lerpDouble(space48, other.space48),
      radiusSmall: lerpDouble(radiusSmall, other.radiusSmall),
      radiusControl: lerpDouble(radiusControl, other.radiusControl),
      radiusCard: lerpDouble(radiusCard, other.radiusCard),
      radiusDialog: lerpDouble(radiusDialog, other.radiusDialog),
      radiusPill: lerpDouble(radiusPill, other.radiusPill),
      displayFontSize: lerpDouble(displayFontSize, other.displayFontSize),
      displayLineHeight: lerpDouble(displayLineHeight, other.displayLineHeight),
      headlineFontSize: lerpDouble(headlineFontSize, other.headlineFontSize),
      headlineLineHeight: lerpDouble(
        headlineLineHeight,
        other.headlineLineHeight,
      ),
      titleFontSize: lerpDouble(titleFontSize, other.titleFontSize),
      titleLineHeight: lerpDouble(titleLineHeight, other.titleLineHeight),
      bodyFontSize: lerpDouble(bodyFontSize, other.bodyFontSize),
      bodyLineHeight: lerpDouble(bodyLineHeight, other.bodyLineHeight),
      labelFontSize: lerpDouble(labelFontSize, other.labelFontSize),
      labelLineHeight: lerpDouble(labelLineHeight, other.labelLineHeight),
      captionFontSize: lerpDouble(captionFontSize, other.captionFontSize),
      captionLineHeight: lerpDouble(captionLineHeight, other.captionLineHeight),
      buttonMinHeight: lerpDouble(buttonMinHeight, other.buttonMinHeight),
      compactButtonHeight: lerpDouble(
        compactButtonHeight,
        other.compactButtonHeight,
      ),
      focusRingWidth: lerpDouble(focusRingWidth, other.focusRingWidth),
      focusOutlineWidth: lerpDouble(focusOutlineWidth, other.focusOutlineWidth),
    );
  }
}

ThemeData easyMeetingTheme(Brightness brightness) {
  final tokens = brightness == Brightness.dark
      ? ThemeTokens.dark
      : ThemeTokens.light;
  final colorScheme = _colorScheme(tokens, brightness);
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(tokens.radiusControl),
  );
  final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(tokens.radiusCard),
  );
  final focusSide = BorderSide(
    color: tokens.focus,
    width: tokens.focusOutlineWidth,
  );
  final normalSide = BorderSide(color: tokens.outlineStrong);

  ButtonStyle statefulButtonStyle({
    required Color foreground,
    required Color background,
    required Color hoverBackground,
    required Color pressedBackground,
    BorderSide? side,
  }) {
    return ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        Size(0, tokens.buttonMinHeight),
      ),
      padding: WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: tokens.space16),
      ),
      shape: WidgetStatePropertyAll(shape),
      foregroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.disabled)
            ? tokens.textPrimary.withValues(alpha: .38)
            : foreground,
      ),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return tokens.textPrimary.withValues(alpha: .12);
        }
        if (states.contains(WidgetState.pressed)) return pressedBackground;
        if (states.contains(WidgetState.hovered)) return hoverBackground;
        return background;
      }),
      overlayColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused)
            ? tokens.focus.withValues(alpha: .12)
            : null,
      ),
      side: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.focused) ? focusSide : side,
      ),
    );
  }

  final textTheme = _textTheme(tokens);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: tokens.background,
    canvasColor: tokens.background,
    dividerColor: tokens.outline,
    focusColor: tokens.focus.withValues(alpha: .12),
    hoverColor: tokens.primary.withValues(alpha: .08),
    splashColor: tokens.primary.withValues(alpha: .12),
    textTheme: textTheme,
    iconTheme: IconThemeData(color: tokens.textSecondary),
    extensions: [tokens],
    appBarTheme: AppBarThemeData(
      backgroundColor: tokens.background,
      foregroundColor: tokens.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: tokens.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: cardShape,
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: statefulButtonStyle(
        foreground: tokens.onPrimary,
        background: tokens.primary,
        hoverBackground: tokens.primaryHover,
        pressedBackground: tokens.primaryPressed,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: statefulButtonStyle(
        foreground: tokens.primary,
        background: Colors.transparent,
        hoverBackground: tokens.primary.withValues(alpha: .08),
        pressedBackground: tokens.primary.withValues(alpha: .12),
        side: normalSide,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: statefulButtonStyle(
        foreground: tokens.primary,
        background: Colors.transparent,
        hoverBackground: tokens.primary.withValues(alpha: .08),
        pressedBackground: tokens.primary.withValues(alpha: .12),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(
          Size(tokens.buttonMinHeight, tokens.buttonMinHeight),
        ),
        shape: WidgetStatePropertyAll(shape),
        iconColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? tokens.textPrimary.withValues(alpha: .38)
              : tokens.textSecondary,
        ),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) {
            return tokens.focus.withValues(alpha: .12);
          }
          if (states.contains(WidgetState.pressed)) {
            return tokens.primary.withValues(alpha: .12);
          }
          if (states.contains(WidgetState.hovered)) {
            return tokens.primary.withValues(alpha: .08);
          }
          return null;
        }),
        side: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.focused) ? focusSide : null,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.surfaceSubtle,
      contentPadding: EdgeInsets.symmetric(
        horizontal: tokens.space16,
        vertical: tokens.space12,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusControl),
        borderSide: normalSide,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusControl),
        borderSide: normalSide,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusControl),
        borderSide: focusSide,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusControl),
        borderSide: BorderSide(color: tokens.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.radiusControl),
        borderSide: BorderSide(
          color: tokens.danger,
          width: tokens.focusRingWidth,
        ),
      ),
      labelStyle: textTheme.labelLarge?.copyWith(color: tokens.textSecondary),
      hintStyle: textTheme.bodyLarge?.copyWith(color: tokens.textSecondary),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: tokens.surface,
      indicatorColor: tokens.primaryContainer,
      selectedIconTheme: IconThemeData(color: tokens.primary),
      unselectedIconTheme: IconThemeData(color: tokens.textSecondary),
      selectedLabelTextStyle: textTheme.labelLarge?.copyWith(
        color: tokens.primary,
      ),
      unselectedLabelTextStyle: textTheme.labelLarge?.copyWith(
        color: tokens.textSecondary,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: tokens.surface,
      indicatorColor: tokens.primaryContainer,
      elevation: 0,
      iconTheme: WidgetStateProperty.resolveWith<IconThemeData?>(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? tokens.primary
              : tokens.textSecondary,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => textTheme.labelLarge?.copyWith(
          color: states.contains(WidgetState.selected)
              ? tokens.primary
              : tokens.textSecondary,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: tokens.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusDialog),
      ),
      titleTextStyle: textTheme.titleLarge,
      contentTextStyle: textTheme.bodyLarge,
    ),
    dividerTheme: DividerThemeData(
      color: tokens.outline,
      thickness: 1,
      space: tokens.space8,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: tokens.surfaceSubtle,
      selectedColor: tokens.primaryContainer,
      disabledColor: tokens.surfaceSubtle.withValues(alpha: .38),
      side: BorderSide(color: tokens.outline),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusPill),
      ),
      labelStyle: textTheme.labelLarge?.copyWith(color: tokens.textPrimary),
      secondaryLabelStyle: textTheme.labelLarge?.copyWith(
        color: tokens.textSecondary,
      ),
      padding: EdgeInsets.symmetric(horizontal: tokens.space12),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: tokens.primary,
      linearTrackColor: tokens.surfaceSubtle,
      circularTrackColor: tokens.surfaceSubtle,
    ),
  );
}

ColorScheme _colorScheme(ThemeTokens tokens, Brightness brightness) {
  return ColorScheme(
    brightness: brightness,
    primary: tokens.primary,
    onPrimary: tokens.onPrimary,
    primaryContainer: tokens.primaryContainer,
    onPrimaryContainer: tokens.textPrimary,
    secondary: tokens.focus,
    onSecondary: tokens.onPrimary,
    secondaryContainer: tokens.surfaceSubtle,
    onSecondaryContainer: tokens.textPrimary,
    tertiary: tokens.success,
    onTertiary: tokens.onPrimary,
    tertiaryContainer: tokens.primaryContainer,
    onTertiaryContainer: tokens.textPrimary,
    error: tokens.danger,
    onError: tokens.onPrimary,
    errorContainer: tokens.surfaceSubtle,
    onErrorContainer: tokens.textPrimary,
    surface: tokens.surface,
    onSurface: tokens.textPrimary,
    surfaceDim: tokens.background,
    surfaceBright: tokens.surface,
    surfaceContainerLowest: tokens.background,
    surfaceContainerLow: tokens.surfaceSubtle,
    surfaceContainer: tokens.surface,
    surfaceContainerHigh: tokens.surfaceSubtle,
    surfaceContainerHighest: tokens.surfaceSubtle,
    onSurfaceVariant: tokens.textSecondary,
    outline: tokens.outline,
    outlineVariant: tokens.outlineStrong,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: tokens.textPrimary,
    onInverseSurface: tokens.background,
    inversePrimary: tokens.primaryHover,
    surfaceTint: tokens.primary,
  );
}

TextTheme _textTheme(ThemeTokens tokens) {
  return TextTheme(
    displayLarge: TextStyle(
      color: tokens.textPrimary,
      fontSize: tokens.displayFontSize,
      height: tokens.displayLineHeight / tokens.displayFontSize,
      fontWeight: FontWeight.w600,
    ),
    headlineLarge: TextStyle(
      color: tokens.textPrimary,
      fontSize: tokens.headlineFontSize,
      height: tokens.headlineLineHeight / tokens.headlineFontSize,
      fontWeight: FontWeight.w600,
    ),
    titleLarge: TextStyle(
      color: tokens.textPrimary,
      fontSize: tokens.titleFontSize,
      height: tokens.titleLineHeight / tokens.titleFontSize,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(
      color: tokens.textPrimary,
      fontSize: tokens.bodyFontSize,
      height: tokens.bodyLineHeight / tokens.bodyFontSize,
      fontWeight: FontWeight.w400,
    ),
    labelLarge: TextStyle(
      color: tokens.textPrimary,
      fontSize: tokens.labelFontSize,
      height: tokens.labelLineHeight / tokens.labelFontSize,
      fontWeight: FontWeight.w500,
    ),
    bodySmall: TextStyle(
      color: tokens.textSecondary,
      fontSize: tokens.captionFontSize,
      height: tokens.captionLineHeight / tokens.captionFontSize,
      fontWeight: FontWeight.w400,
    ),
  );
}
