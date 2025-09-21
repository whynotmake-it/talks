/// Shared resources for flutter slides
library wnma_talk;

import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_deck/flutter_deck.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wnmi_design/wnmi_design.dart';

export 'package:device_frame/device_frame.dart';
export 'package:flutter_deck/flutter_deck.dart';
export 'package:flutter_highlight/flutter_highlight.dart';
export 'package:wnmi_design/wnmi_design.dart';

FlutterDeckThemeData buildTalkTheme() {
  final colorScheme = _buildColorScheme();
  final textTheme = _buildTextTheme();

  return FlutterDeckThemeData.fromThemeAndText(
    ThemeData.from(
      colorScheme: colorScheme,
    ),
    textTheme,
  ).copyWith(
    codeHighlightTheme: FlutterDeckCodeHighlightThemeData(
      textStyle: GoogleFonts.sourceCodePro(),
    ),
  );
  ;
}

ColorScheme _buildColorScheme() {
  const primary = ColorsPrimary.standard();
  const secondary = ColorsSecondary.standard();
  const tertiary = ColorsAccent.standard();
  const error = ColorsError.standard();

  final scheme = SeedColorScheme.fromSeeds(
    variant: FlexSchemeVariant.highContrast,
    primaryKey: primary.$50,
    secondaryKey: secondary.$50,
    tertiaryKey: tertiary.$50,
    errorKey: error.$50,
  );

  return scheme;
}

FlutterDeckThemeData buildGaussianSplattingTheme() {
  final colorScheme = _buildGaussianSplattingColorScheme();
  final textTheme = _buildTextTheme();

  return FlutterDeckThemeData.fromThemeAndText(
    ThemeData.from(
      colorScheme: colorScheme,
    ),
    textTheme,
  ).copyWith(
    codeHighlightTheme: FlutterDeckCodeHighlightThemeData(
      textStyle: GoogleFonts.sourceCodePro(),
    ),
  );
}

ColorScheme _buildGaussianSplattingColorScheme() {
  // Light mode: Clean whites with vibrant tech-inspired accent colors
  const primary = Color(0xFF0288D1); // Deep sky blue
  const secondary = Color(0xFF00ACC1); // Cyan
  const tertiary = Color(0xFFE91E63); // Pink
  const surface = Color(0xFFFAFDFF); // Pure white with hint of blue
  const error = Color(0xFFD32F2F);

  final scheme =
      SeedColorScheme.fromSeeds(
        variant: FlexSchemeVariant.vivid,
        primaryKey: primary,
        secondaryKey: secondary,
        tertiaryKey: tertiary,
        errorKey: error,
      ).copyWith(
        surface: surface,
        onSurface: const Color(0xFF0D1B2A),
        surfaceContainerHighest: const Color(0xFFF0F8FF),
        primaryContainer: const Color(0xFFE1F5FE),
        onPrimaryContainer: const Color(0xFF01579B),
        secondaryContainer: const Color(0xFFE0F2F1),
        onSecondaryContainer: const Color(0xFF004D40),
        outline: const Color(0xFFB0BEC5),
        outlineVariant: const Color(0xFFE0E0E0),
      );

  return scheme;
}

FlutterDeckTextTheme _buildTextTheme() {
  final display = TypographyDisplay.standard();
  final body = TypographyBody.standard();
  return FlutterDeckTextTheme(
    bodySmall: body.small.copyWith(fontSize: 24),
    bodyMedium: body.medium.copyWith(fontSize: 32),
    bodyLarge: body.large.copyWith(
      fontSize: 36,
      height: 1.2,
    ),
    display: display.large.copyWith(fontSize: 96),
    title: display.medium.copyWith(
      fontSize: 190,
      fontWeight: FontWeight.w300,
      letterSpacing: 1,
      height: .96,
    ),
    subtitle: display.medium.copyWith(
      fontSize: 60,
      fontWeight: FontWeight.w300,
      letterSpacing: 1,
      height: .96,
    ),
    header: display.small,
  );
}
