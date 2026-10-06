import 'dart:ui';

import 'package:flutter/material.dart';

// Tokens taken from motor's example gallery and motor_devtools
// (rivership packages/motor/example/lib/widgets/style.dart), with the type
// scale sized for a 1920×1080 slide.

/// Zinc neutrals and one blue-violet accent, for light and dark mode.
enum Palette {
  light(
    canvas: Color(0xFFF4F4F5),
    surface: Color(0xFFFFFFFF),
    inset: Color(0xFFFAFAFA),
    control: Color(0xFFE9E9EC),
    border: Color(0xFFE4E4E7),
    borderStrong: Color(0xFFD4D4D8),
    text: Color(0xFF18181B),
    textSecondary: Color(0xFF52525B),
    textTertiary: Color(0xFFA1A1AA),
    accent: Color(0xFF3D63DD),
    onAccent: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFE3E9FB),
  ),
  dark(
    canvas: Color(0xFF111113),
    surface: Color(0xFF1C1C1F),
    inset: Color(0xFF161618),
    control: Color(0xFF28282C),
    border: Color(0xFF2A2A2E),
    borderStrong: Color(0xFF3F3F46),
    text: Color(0xFFFAFAFA),
    textSecondary: Color(0xFFA1A1AA),
    textTertiary: Color(0xFF71717A),
    accent: Color(0xFF8AA4FF),
    onAccent: Color(0xFF111113),
    accentSoft: Color(0xFF1E2544),
  );

  const Palette({
    required this.canvas,
    required this.surface,
    required this.inset,
    required this.control,
    required this.border,
    required this.borderStrong,
    required this.text,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
  });

  /// The slide background.
  final Color canvas;

  /// Cards and panels.
  final Color surface;

  /// Recessed areas, like the stage a demo plays on.
  final Color inset;

  /// Resting fill of controls.
  final Color control;

  final Color border;
  final Color borderStrong;
  final Color text;
  final Color textSecondary;
  final Color textTertiary;

  /// The one color with character. Use it sparingly.
  final Color accent;

  /// Text and icons on [accent].
  final Color onAccent;

  /// A quiet tint of [accent].
  final Color accentSoft;

  /// The palette for the deck's theme mode, which flutter_deck lets the
  /// presenter toggle.
  static Palette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// The spectrum red from example_design, reserved for GPU cost ("heat").
const heat = Color(0xFFFA3D1D);

/// Corner radius of surfaces and controls. Square: the rounded shapes are the
/// things being animated.
const radius = 0.0;

/// A strong ease-out, for things that enter or respond.
const easeOut = Cubic(.23, 1, .32, 1);

/// A strong ease-in-out, for things that move on screen.
const easeInOut = Cubic(.77, 0, .175, 1);

/// Archivo at a given weight and width. Both are variable-font axes, so they
/// are set as variations as well as [FontWeight].
TextStyle archivo(
  double size, {
  double weight = 400,
  double width = 100,
  double? height,
  double spacing = 0,
  Color? color,
}) => TextStyle(
  fontFamily: 'Archivo',
  fontSize: size,
  fontWeight: FontWeight.lerp(
    FontWeight.w100,
    FontWeight.w900,
    ((weight - 100) / 800).clamp(0, 1),
  ),
  fontVariations: [FontVariation.weight(weight), FontVariation.width(width)],
  height: height,
  letterSpacing: spacing,
  color: color,
);

/// JetBrains Mono, for labels, numbers and code.
TextStyle mono(
  double size, {
  double weight = 440,
  double spacing = 0,
  double? height,
  Color? color,
}) => TextStyle(
  fontFamily: 'JetBrains Mono',
  fontSize: size,
  fontVariations: [FontVariation.weight(weight)],
  letterSpacing: spacing,
  height: height,
  color: color,
);

/// The deck's type scale, resolved against a palette.
extension TypeScaleTools on Palette {
  /// The talk title.
  TextStyle get hero =>
      archivo(168, weight: 380, height: .98, spacing: -7, color: text);

  /// Slide titles.
  TextStyle get display =>
      archivo(104, height: 1.02, spacing: -3.6, color: text);

  /// Card and section titles.
  TextStyle get title =>
      archivo(44, weight: 500, height: 1.2, spacing: -.6, color: text);

  /// Body copy.
  TextStyle get body =>
      archivo(36, height: 1.45, spacing: -.1, color: textSecondary);

  /// Small print.
  TextStyle get caption => archivo(24, height: 1.35, color: textTertiary);

  /// Uppercase labels.
  TextStyle get eyebrow =>
      mono(24, weight: 500, spacing: 1.2, color: textTertiary);

  /// Code.
  TextStyle get code => mono(28, height: 1.45, color: textSecondary);
}

/// Blurs [child] by [sigma] on each axis. Skips the filter when it is too
/// small to see.
class Blur extends StatelessWidget {
  const Blur({required this.sigma, required this.child, super.key});

  /// Horizontal and vertical blur sigma.
  final Offset sigma;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (sigma.dx < .05 && sigma.dy < .05) return child;
    return ImageFiltered(
      imageFilter: ImageFilter.blur(
        sigmaX: sigma.dx,
        sigmaY: sigma.dy,
        tileMode: TileMode.decal,
      ),
      child: child,
    );
  }
}

/// Fades [child] in and moves it by [offset] as [progress] goes from 0 to 1.
/// A light [blur] blends the in-between frames of a crossfade.
class Reveal extends StatelessWidget {
  const Reveal({
    required this.progress,
    required this.child,
    this.offset = const Offset(0, 16),
    this.blur = 2,
    super.key,
  });

  final double progress;
  final Offset offset;
  final double blur;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hidden = 1 - progress.clamp(0.0, 1.0);
    return Opacity(
      opacity: 1 - hidden,
      child: Transform.translate(
        offset: offset * hidden,
        child: Blur(sigma: Offset(hidden, hidden) * blur, child: child),
      ),
    );
  }
}
