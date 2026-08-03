import 'package:flutter/material.dart';

@immutable
class ThemeTokens extends ThemeExtension<ThemeTokens> {
  const ThemeTokens({
    required this.accentPrimary,
    required this.accentSecondary,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.recording,
    this.cornerRadius = 12,
    this.spacingUnit = 8,
  });

  final Color accentPrimary;
  final Color accentSecondary;
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color recording;
  final double cornerRadius;
  final double spacingUnit;

  static const light = ThemeTokens(
    accentPrimary: Color(0xFF6366F1),
    accentSecondary: Color(0xFFADC6FF),
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFAF9FE),
    textPrimary: Color(0xFF1A1B1F),
    textSecondary: Color(0xFF6B6F76),
    recording: Color(0xFFFF3B30),
  );

  static const dark = ThemeTokens(
    accentPrimary: Color(0xFF6366F1),
    accentSecondary: Color(0xFFC0C1FF),
    background: Color(0xFF0B1326),
    surface: Color(0xFF2D3449),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFA8ADB8),
    recording: Color(0xFFFFB4AB),
  );

  @override
  ThemeTokens copyWith({
    Color? accentPrimary,
    Color? accentSecondary,
    Color? background,
    Color? surface,
    Color? textPrimary,
    Color? textSecondary,
    Color? recording,
    double? cornerRadius,
    double? spacingUnit,
  }) => ThemeTokens(
    accentPrimary: accentPrimary ?? this.accentPrimary,
    accentSecondary: accentSecondary ?? this.accentSecondary,
    background: background ?? this.background,
    surface: surface ?? this.surface,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    recording: recording ?? this.recording,
    cornerRadius: cornerRadius ?? this.cornerRadius,
    spacingUnit: spacingUnit ?? this.spacingUnit,
  );

  @override
  ThemeTokens lerp(covariant ThemeTokens? other, double t) {
    if (other == null) return this;
    return ThemeTokens(
      accentPrimary: Color.lerp(accentPrimary, other.accentPrimary, t)!,
      accentSecondary: Color.lerp(accentSecondary, other.accentSecondary, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      recording: Color.lerp(recording, other.recording, t)!,
      cornerRadius: cornerRadius + (other.cornerRadius - cornerRadius) * t,
      spacingUnit: spacingUnit + (other.spacingUnit - spacingUnit) * t,
    );
  }
}

ThemeData easyMeetingTheme(Brightness brightness) {
  final tokens = brightness == Brightness.dark
      ? ThemeTokens.dark
      : ThemeTokens.light;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: tokens.accentPrimary,
      brightness: brightness,
      surface: tokens.surface,
    ),
    scaffoldBackgroundColor: tokens.background,
    extensions: [tokens],
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(tokens.cornerRadius),
      ),
    ),
    cardTheme: CardThemeData(
      color: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.cornerRadius),
      ),
    ),
  );
}
