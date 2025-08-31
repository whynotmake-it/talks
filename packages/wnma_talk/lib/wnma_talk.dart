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
      backgroundColor: colorScheme.surfaceContainerHighest,
      textStyle: GoogleFonts.sourceCodePro(
        fontSize: 24,
      ),
    ),
  );
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
