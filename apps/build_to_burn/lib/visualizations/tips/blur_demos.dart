import 'dart:math' as math;
import 'dart:ui';

import 'package:build_to_burn/shared/style.dart';
import 'package:build_to_burn/visualizations/tips/tip_kit.dart';
import 'package:flutter/widgets.dart';

/// The downsample factor Impeller picks for a blur of [sigma] physical
/// pixels: 1 up to sigma 4, then the nearest 1/2ⁿ of 4 / sigma.
///
/// Mirrors `GaussianBlurFilterContents::CalculateScale` (Flutter 3.47.1).
/// The engine's extra rule below 1/8 never applies here: the demo stays under
/// sigma 45.
double blurScale(double sigma) {
  if (sigma <= 4) return 1;
  final exponent = (math.log(4 / sigma) / math.ln2).roundToDouble();
  return math.pow(2, math.max(-4, exponent)).toDouble();
}

/// A circle blurs more and more. Next to it, the texture the blur runs on
/// drops to half its size at each cliff.
class SigmaDownsampleDemo extends StatelessWidget {
  const SigmaDownsampleDemo({super.key});

  static const _box = 300.0;

  /// Cells of the full-size texture, per side.
  static const _cells = 32;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Loop(
      period: const Duration(seconds: 10),
      builder: (context, t) {
        final sigma = 40 * (phase(t, .05, .45) - phase(t, .6, .95));
        final scale = blurScale(sigma);
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox.square(
              dimension: _box,
              child: Center(
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: sigma,
                    sigmaY: sigma,
                    tileMode: TileMode.decal,
                  ),
                  child: Container(
                    width: _box * .55,
                    height: _box * .55,
                    decoration: BoxDecoration(
                      color: p.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            // The full-size texture's outline, for comparison.
            Container(
              width: _box,
              height: _box,
              decoration: BoxDecoration(
                border: Border.all(color: p.border, width: 2),
              ),
              child: Center(
                child: CustomPaint(
                  size: Size.square(_box * scale),
                  painter: _TexturePainter(
                    cells: (_cells * scale).round(),
                    fill: p.accent,
                    empty: p.inset,
                    grid: p.borderStrong,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A square texture of [cells]² pixels holding the circle, pixelated.
class _TexturePainter extends CustomPainter {
  const _TexturePainter({
    required this.cells,
    required this.fill,
    required this.empty,
    required this.grid,
  });

  final int cells;
  final Color fill;
  final Color empty;
  final Color grid;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / cells;
    const radius = .55 / 2;
    final paint = Paint();
    for (var y = 0; y < cells; y++) {
      for (var x = 0; x < cells; x++) {
        // Coverage of the circle in this pixel, from 4×4 samples.
        var hits = 0;
        for (var sy = 0; sy < 4; sy++) {
          for (var sx = 0; sx < 4; sx++) {
            final u = (x + (sx + .5) / 4) / cells - .5;
            final v = (y + (sy + .5) / 4) / cells - .5;
            if (u * u + v * v <= radius * radius) hits++;
          }
        }
        paint.color = Color.lerp(empty, fill, hits / 16)!;
        canvas.drawRect(
          Rect.fromLTWH(x * cell, y * cell, cell, cell),
          paint,
        );
      }
    }
    final line = Paint()
      ..color = grid
      ..strokeWidth = 1.5;
    for (var i = 0; i <= cells; i++) {
      canvas
        ..drawLine(Offset(i * cell, 0), Offset(i * cell, size.height), line)
        ..drawLine(Offset(0, i * cell), Offset(size.width, i * cell), line);
    }
  }

  @override
  bool shouldRepaint(_TexturePainter old) =>
      old.cells != cells ||
      old.fill != fill ||
      old.empty != empty ||
      old.grid != grid;
}

/// Two glass panes with their own blur, next to two that share one blur.
class GroupedBlurDemo extends StatelessWidget {
  const GroupedBlurDemo({super.key});

  @override
  Widget build(BuildContext context) {
    // Passes measured on macOS Metal for two backdrops, ungrouped and
    // grouped (impeeler-gpu-cost, reducing-cost.md).
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _GlassPair(grouped: false, passes: 11),
        _GlassPair(grouped: true, passes: 5),
      ],
    );
  }
}

class _GlassPair extends StatelessWidget {
  const _GlassPair({required this.grouped, required this.passes});

  final bool grouped;
  final int passes;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget pane(double sigma) {
      final glass = DecoratedBox(
        decoration: BoxDecoration(
          color: p.surface.withValues(alpha: .4),
          border: Border.all(color: p.borderStrong, width: 3),
          borderRadius: BorderRadius.circular(16),
        ),
      );
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 220,
          height: 150,
          child: grouped
              ? BackdropFilter.grouped(
                  filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: glass,
                )
              : BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: glass,
                ),
        ),
      );
    }

    final panes = Stack(
      children: [
        const Positioned.fill(child: _Drift()),
        Positioned(left: 40, top: 70, child: pane(grouped ? 18 : 4)),
        Positioned(left: 40, top: 300, child: pane(grouped ? 18 : 36)),
        // A solid outline around both panes: one group.
        if (grouped)
          Positioned(
            left: 20,
            top: 50,
            width: 260,
            height: 420,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: p.accent, width: 4),
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
      ],
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 300,
          height: 520,
          child: ClipRect(
            child: grouped ? BackdropGroup(child: panes) : panes,
          ),
        ),
        const SizedBox(height: 40),
        PassBars(count: passes, slots: 11),
      ],
    );
  }
}

/// Colored circles drifting, so the backdrop blurs have something to blur.
class _Drift extends StatelessWidget {
  const _Drift();

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final colors = [p.accent, heat, p.text];
    return Loop(
      period: const Duration(seconds: 6),
      builder: (context, t) => Stack(
        children: [
          for (var i = 0; i < 3; i++)
            Positioned(
              left: 150 + 110 * math.cos((t + i / 3) * math.pi * 2) - 50,
              top: 260 + 200 * math.sin((t + i / 3) * math.pi * 2) - 50,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: colors[i],
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Two blurs fade out. One stops just above zero and keeps its passes; the
/// other reaches exactly zero and loses them.
class SigmaZeroDemo extends StatelessWidget {
  const SigmaZeroDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Loop(
      period: const Duration(seconds: 7),
      builder: (context, t) {
        final fade = phase(t, .1, .4) - phase(t, .75, .95);
        final sigma = 24 * (1 - fade);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _FadingBlur(sigma: math.max(sigma, .001)),
            _FadingBlur(sigma: sigma),
          ],
        );
      },
    );
  }
}

class _FadingBlur extends StatelessWidget {
  const _FadingBlur({required this.sigma});

  final double sigma;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final circle = Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
    );
    final label = sigma == 0
        ? '0'
        : sigma < .05
        ? sigma.toStringAsFixed(3)
        : sigma.toStringAsFixed(1);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'σ $label',
          style: mono(30, weight: 500, color: p.textSecondary),
        ),
        SizedBox.square(
          dimension: 300,
          child: Center(
            child: sigma == 0
                ? circle
                : ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: sigma,
                      sigmaY: sigma,
                      tileMode: TileMode.decal,
                    ),
                    child: circle,
                  ),
          ),
        ),
        const SizedBox(height: 40),
        // A Gaussian blur is three passes.
        PassBars(count: sigma == 0 ? 0 : 3, slots: 3),
      ],
    );
  }
}
