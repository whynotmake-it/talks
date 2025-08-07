// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

@immutable
class TypographyHeadline extends ThemeExtension<TypographyHeadline> {
  const TypographyHeadline({
    required this.large,
    required this.medium,
    required this.small,
  });

  TypographyHeadline.standard()
      : large = GoogleFonts.getFont(
          'Darker Grotesque',
          fontSize: 32.0,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.normal,
          letterSpacing: 0.0,
          height: 0.699999988079071,
          decoration: TextDecoration.none,
        ),
        medium = GoogleFonts.getFont(
          'Darker Grotesque',
          fontSize: 28.0,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.normal,
          letterSpacing: 0.0,
          height: 0.7000000136239188,
          decoration: TextDecoration.none,
        ),
        small = GoogleFonts.getFont(
          'Darker Grotesque',
          fontSize: 24.0,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.normal,
          letterSpacing: 0.0,
          height: 0.6999999682108561,
          decoration: TextDecoration.none,
        );

  final TextStyle large;

  final TextStyle medium;

  final TextStyle small;

  @override
  TypographyHeadline copyWith([
    TextStyle? large,
    TextStyle? medium,
    TextStyle? small,
  ]) =>
      TypographyHeadline(
        large: large ?? this.large,
        medium: medium ?? this.medium,
        small: small ?? this.small,
      );

  @override
  TypographyHeadline lerp(
    TypographyHeadline? other,
    double t,
  ) {
    if (other is! TypographyHeadline) return this;
    return TypographyHeadline(
      large: TextStyle.lerp(
        large,
        other.large,
        t,
      )!,
      medium: TextStyle.lerp(
        medium,
        other.medium,
        t,
      )!,
      small: TextStyle.lerp(
        small,
        other.small,
        t,
      )!,
    );
  }
}

extension TypographyHeadlineBuildContextX on BuildContext {
  TypographyHeadline get typographyHeadline =>
      Theme.of(this).extension<TypographyHeadline>()!;
}

@immutable
class TypographyDisplay extends ThemeExtension<TypographyDisplay> {
  const TypographyDisplay({
    required this.large,
    required this.medium,
    required this.small,
  });

  TypographyDisplay.standard()
      : large = GoogleFonts.getFont(
          'Darker Grotesque',
          fontSize: 51.0,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.normal,
          letterSpacing: -1.53,
          height: 0.7000000149595971,
          decoration: TextDecoration.none,
        ),
        medium = GoogleFonts.getFont(
          'Darker Grotesque',
          fontSize: 45.0,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.normal,
          letterSpacing: -0.9,
          height: 0.7,
          decoration: TextDecoration.none,
        ),
        small = GoogleFonts.getFont(
          'Darker Grotesque',
          fontSize: 36.0,
          fontWeight: FontWeight.w500,
          fontStyle: FontStyle.normal,
          letterSpacing: 0.0,
          height: 0.6999999682108561,
          decoration: TextDecoration.none,
        );

  final TextStyle large;

  final TextStyle medium;

  final TextStyle small;

  @override
  TypographyDisplay copyWith([
    TextStyle? large,
    TextStyle? medium,
    TextStyle? small,
  ]) =>
      TypographyDisplay(
        large: large ?? this.large,
        medium: medium ?? this.medium,
        small: small ?? this.small,
      );

  @override
  TypographyDisplay lerp(
    TypographyDisplay? other,
    double t,
  ) {
    if (other is! TypographyDisplay) return this;
    return TypographyDisplay(
      large: TextStyle.lerp(
        large,
        other.large,
        t,
      )!,
      medium: TextStyle.lerp(
        medium,
        other.medium,
        t,
      )!,
      small: TextStyle.lerp(
        small,
        other.small,
        t,
      )!,
    );
  }
}

extension TypographyDisplayBuildContextX on BuildContext {
  TypographyDisplay get typographyDisplay =>
      Theme.of(this).extension<TypographyDisplay>()!;
}

@immutable
class TypographyBody extends ThemeExtension<TypographyBody> {
  const TypographyBody({
    required this.large,
    required this.medium,
    required this.small,
  });

  TypographyBody.standard()
      : large = GoogleFonts.getFont(
          'Inter',
          fontSize: 16.0,
          fontWeight: FontWeight.w400,
          fontStyle: FontStyle.normal,
          letterSpacing: 0.0,
          height: 1.5,
          decoration: TextDecoration.none,
        ),
        medium = GoogleFonts.getFont(
          'Inter',
          fontSize: 14.0,
          fontWeight: FontWeight.w400,
          fontStyle: FontStyle.normal,
          letterSpacing: 0.0,
          height: 1.4000000272478377,
          decoration: TextDecoration.none,
        ),
        small = GoogleFonts.getFont(
          'Inter',
          fontSize: 12.0,
          fontWeight: FontWeight.w400,
          fontStyle: FontStyle.normal,
          letterSpacing: 0.0,
          height: 1.3300000826517742,
          decoration: TextDecoration.none,
        );

  final TextStyle large;

  final TextStyle medium;

  final TextStyle small;

  @override
  TypographyBody copyWith([
    TextStyle? large,
    TextStyle? medium,
    TextStyle? small,
  ]) =>
      TypographyBody(
        large: large ?? this.large,
        medium: medium ?? this.medium,
        small: small ?? this.small,
      );

  @override
  TypographyBody lerp(
    TypographyBody? other,
    double t,
  ) {
    if (other is! TypographyBody) return this;
    return TypographyBody(
      large: TextStyle.lerp(
        large,
        other.large,
        t,
      )!,
      medium: TextStyle.lerp(
        medium,
        other.medium,
        t,
      )!,
      small: TextStyle.lerp(
        small,
        other.small,
        t,
      )!,
    );
  }
}

extension TypographyBodyBuildContextX on BuildContext {
  TypographyBody get typographyBody =>
      Theme.of(this).extension<TypographyBody>()!;
}

@immutable
class TypographyLabel extends ThemeExtension<TypographyLabel> {
  const TypographyLabel({
    required this.large,
    required this.medium,
    required this.small,
  });

  TypographyLabel.standard()
      : large = GoogleFonts.getFont(
          'Inter',
          fontSize: 14.0,
          fontWeight: FontWeight.w400,
          fontStyle: FontStyle.normal,
          letterSpacing: 0.42,
          height: 1.5,
          decoration: TextDecoration.none,
        ),
        medium = GoogleFonts.getFont(
          'Inter',
          fontSize: 12.0,
          fontWeight: FontWeight.w400,
          fontStyle: FontStyle.normal,
          letterSpacing: 0.6000000000000001,
          height: 1.3999999364217122,
          decoration: TextDecoration.none,
        ),
        small = GoogleFonts.getFont(
          'Inter',
          fontSize: 11.0,
          fontWeight: FontWeight.w400,
          fontStyle: FontStyle.normal,
          letterSpacing: 0.88,
          height: 1.3300000104037197,
          decoration: TextDecoration.none,
        );

  final TextStyle large;

  final TextStyle medium;

  final TextStyle small;

  @override
  TypographyLabel copyWith([
    TextStyle? large,
    TextStyle? medium,
    TextStyle? small,
  ]) =>
      TypographyLabel(
        large: large ?? this.large,
        medium: medium ?? this.medium,
        small: small ?? this.small,
      );

  @override
  TypographyLabel lerp(
    TypographyLabel? other,
    double t,
  ) {
    if (other is! TypographyLabel) return this;
    return TypographyLabel(
      large: TextStyle.lerp(
        large,
        other.large,
        t,
      )!,
      medium: TextStyle.lerp(
        medium,
        other.medium,
        t,
      )!,
      small: TextStyle.lerp(
        small,
        other.small,
        t,
      )!,
    );
  }
}

extension TypographyLabelBuildContextX on BuildContext {
  TypographyLabel get typographyLabel =>
      Theme.of(this).extension<TypographyLabel>()!;
}
