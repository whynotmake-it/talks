/// Shared resources for flutter slides
library wnma_talk;

import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_deck/flutter_deck.dart';
import 'package:wnmi_design/wnmi_design.dart';

export 'package:flutter_deck/flutter_deck.dart';
export 'package:wnmi_design/wnmi_design.dart';

FlutterDeckThemeData buildTalkTheme() {
  final colorScheme = _buildColorScheme();
  final textTheme = _buildTextTheme();

  return FlutterDeckThemeData.fromThemeAndText(
    ThemeData.from(
      colorScheme: colorScheme,
    ),
    textTheme,
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
    bodyLarge: body.large,
    bodyMedium: body.medium,
    bodySmall: body.small,
    display: display.large.copyWith(fontSize: 274),
    title: display.medium,
    header: display.small,
  );
}
