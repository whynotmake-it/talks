import 'package:build_to_burn/shared/style.dart';
import 'package:flutter/material.dart';
import 'package:wnma_talk/wnma_talk.dart';

/// The flutter_deck theme for [palette], so flutter_deck's own chrome
/// (navigation drawer, code highlight, templates) matches the slides.
FlutterDeckThemeData buildDeckTheme(Palette palette, Brightness brightness) {
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: palette.accent,
        brightness: brightness,
      ).copyWith(
        primary: palette.accent,
        onPrimary: palette.onAccent,
        primaryContainer: palette.accentSoft,
        surface: palette.canvas,
        onSurface: palette.text,
        onSurfaceVariant: palette.textSecondary,
        surfaceContainerHighest: palette.surface,
        outline: palette.borderStrong,
        outlineVariant: palette.border,
      );

  return FlutterDeckThemeData.fromThemeAndText(
    ThemeData.from(colorScheme: colorScheme),
    FlutterDeckTextTheme(
      display: palette.display,
      header: palette.title,
      subtitle: palette.title.copyWith(color: palette.textSecondary),
      title: palette.hero,
      bodyLarge: palette.body,
      bodyMedium: palette.body.copyWith(fontSize: 30),
      bodySmall: palette.caption,
    ),
  ).copyWith(
    codeHighlightTheme: FlutterDeckCodeHighlightThemeData(
      textStyle: palette.code,
    ),
  );
}
