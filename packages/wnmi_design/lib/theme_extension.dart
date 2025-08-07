import 'package:flutter/material.dart';
import 'package:wnmi_design/wnmi_design.dart';

/// Provides [withWnmiDesign]
extension WnmiDesignThemeExtension on ThemeData {
  /// Adds the wnmi design theme extensions to the current theme
  ThemeData withWnmiDesign() => copyWith(
        extensions: [
          ...extensions.values,
          const ColorsPrimary.standard(),
          const ColorsSecondary.standard(),
          const ColorsAccent.standard(),
          const ColorsError.standard(),
          TypographyBody.standard(),
          TypographyDisplay.standard(),
          TypographyHeadline.standard(),
          TypographyLabel.standard(),
        ],
      );
}
