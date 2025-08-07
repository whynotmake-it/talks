// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:flutter/material.dart';

@immutable
class ColorsPrimary extends ThemeExtension<ColorsPrimary> {
  const ColorsPrimary({
    required this.$10,
    required this.$30,
    required this.$50,
    required this.$70,
    required this.$90,
  });

  const ColorsPrimary.standard()
      : $10 = const Color(0xffe1f7e4),
        $30 = const Color(0xff98dda1),
        $50 = const Color(0xff43b752),
        $70 = const Color(0xff276e31),
        $90 = const Color(0xff1f4825);

  final Color $10;

  final Color $30;

  final Color $50;

  final Color $70;

  final Color $90;

  @override
  ColorsPrimary copyWith([
    Color? $10,
    Color? $30,
    Color? $50,
    Color? $70,
    Color? $90,
  ]) =>
      ColorsPrimary(
        $10: $10 ?? this.$10,
        $30: $30 ?? this.$30,
        $50: $50 ?? this.$50,
        $70: $70 ?? this.$70,
        $90: $90 ?? this.$90,
      );

  @override
  ColorsPrimary lerp(
    ColorsPrimary? other,
    double t,
  ) {
    if (other is! ColorsPrimary) return this;
    return ColorsPrimary(
      $10: Color.lerp(
        $10,
        other.$10,
        t,
      )!,
      $30: Color.lerp(
        $30,
        other.$30,
        t,
      )!,
      $50: Color.lerp(
        $50,
        other.$50,
        t,
      )!,
      $70: Color.lerp(
        $70,
        other.$70,
        t,
      )!,
      $90: Color.lerp(
        $90,
        other.$90,
        t,
      )!,
    );
  }
}

extension ColorsPrimaryBuildContextX on BuildContext {
  ColorsPrimary get colorsPrimary => Theme.of(this).extension<ColorsPrimary>()!;
}

@immutable
class ColorsSecondary extends ThemeExtension<ColorsSecondary> {
  const ColorsSecondary({
    required this.$10,
    required this.$30,
    required this.$50,
    required this.$70,
    required this.$90,
  });

  const ColorsSecondary.standard()
      : $10 = const Color(0xffe0ecfc),
        $30 = const Color(0xffa4ccf7),
        $50 = const Color(0xff6399ed),
        $70 = const Color(0xff3763d7),
        $90 = const Color(0xff274592);

  final Color $10;

  final Color $30;

  final Color $50;

  final Color $70;

  final Color $90;

  @override
  ColorsSecondary copyWith([
    Color? $10,
    Color? $30,
    Color? $50,
    Color? $70,
    Color? $90,
  ]) =>
      ColorsSecondary(
        $10: $10 ?? this.$10,
        $30: $30 ?? this.$30,
        $50: $50 ?? this.$50,
        $70: $70 ?? this.$70,
        $90: $90 ?? this.$90,
      );

  @override
  ColorsSecondary lerp(
    ColorsSecondary? other,
    double t,
  ) {
    if (other is! ColorsSecondary) return this;
    return ColorsSecondary(
      $10: Color.lerp(
        $10,
        other.$10,
        t,
      )!,
      $30: Color.lerp(
        $30,
        other.$30,
        t,
      )!,
      $50: Color.lerp(
        $50,
        other.$50,
        t,
      )!,
      $70: Color.lerp(
        $70,
        other.$70,
        t,
      )!,
      $90: Color.lerp(
        $90,
        other.$90,
        t,
      )!,
    );
  }
}

extension ColorsSecondaryBuildContextX on BuildContext {
  ColorsSecondary get colorsSecondary =>
      Theme.of(this).extension<ColorsSecondary>()!;
}

@immutable
class ColorsAccent extends ThemeExtension<ColorsAccent> {
  const ColorsAccent({required this.$50});

  const ColorsAccent.standard() : $50 = const Color(0xff7d7be7);

  final Color $50;

  @override
  ColorsAccent copyWith([Color? $50]) => ColorsAccent($50: $50 ?? this.$50);

  @override
  ColorsAccent lerp(
    ColorsAccent? other,
    double t,
  ) {
    if (other is! ColorsAccent) return this;
    return ColorsAccent(
        $50: Color.lerp(
      $50,
      other.$50,
      t,
    )!);
  }
}

extension ColorsAccentBuildContextX on BuildContext {
  ColorsAccent get colorsAccent => Theme.of(this).extension<ColorsAccent>()!;
}

@immutable
class ColorsError extends ThemeExtension<ColorsError> {
  const ColorsError({
    required this.$10,
    required this.$30,
    required this.$50,
    required this.$70,
    required this.$90,
  });

  const ColorsError.standard()
      : $10 = const Color(0xfffff2f2),
        $30 = const Color(0xffffaaac),
        $50 = const Color(0xfff7585c),
        $70 = const Color(0xffd2171c),
        $90 = const Color(0xff911a1d);

  final Color $10;

  final Color $30;

  final Color $50;

  final Color $70;

  final Color $90;

  @override
  ColorsError copyWith([
    Color? $10,
    Color? $30,
    Color? $50,
    Color? $70,
    Color? $90,
  ]) =>
      ColorsError(
        $10: $10 ?? this.$10,
        $30: $30 ?? this.$30,
        $50: $50 ?? this.$50,
        $70: $70 ?? this.$70,
        $90: $90 ?? this.$90,
      );

  @override
  ColorsError lerp(
    ColorsError? other,
    double t,
  ) {
    if (other is! ColorsError) return this;
    return ColorsError(
      $10: Color.lerp(
        $10,
        other.$10,
        t,
      )!,
      $30: Color.lerp(
        $30,
        other.$30,
        t,
      )!,
      $50: Color.lerp(
        $50,
        other.$50,
        t,
      )!,
      $70: Color.lerp(
        $70,
        other.$70,
        t,
      )!,
      $90: Color.lerp(
        $90,
        other.$90,
        t,
      )!,
    );
  }
}

extension ColorsErrorBuildContextX on BuildContext {
  ColorsError get colorsError => Theme.of(this).extension<ColorsError>()!;
}
