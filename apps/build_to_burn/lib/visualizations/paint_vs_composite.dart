import 'package:build_to_burn/shared/style.dart';
import 'package:build_to_burn/visualizations/blinking_caret.dart';
import 'package:build_to_burn/visualizations/blur_scenario.dart';
import 'package:build_to_burn/visualizations/blur_sheet_screen.dart';
import 'package:flutter/material.dart';
import 'package:motor/motor.dart';

/// The aha: the same screen twice. On the left, what repaints on the UI
/// thread (only the caret, only when its pixels change). On the right, what
/// the raster thread and GPU redo (the whole screen, every frame). Next to
/// them, GPU work = how often × how hard, for [scenario].
///
/// Step through [BlurScenario.ahaSequence] with deck steps. The widget
/// scales to its box, keeping [designSize]'s aspect ratio.
class PaintVsComposite extends StatelessWidget {
  const PaintVsComposite({
    required this.scenario,
    this.showCaption = true,
    super.key,
  });

  final BlurScenario scenario;

  /// Whether to show [BlurScenario.caption] under the formula.
  final bool showCaption;

  static const designSize = Size(1600, 640);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return FittedBox(
      child: SizedBox.fromSize(
        size: designSize,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Pane(
              label: 'Repaints',
              sublabel: 'UI thread',
              child: BlurSheetScreen(
                blur: scenario.blur,
                caret: scenario.caret,
                caretOverlay: RepaintFlash(caret: scenario.caret),
              ),
            ),
            const SizedBox(width: 40),
            _Pane(
              label: 'Re-rendered',
              sublabel: 'Raster thread + GPU',
              child: BlurSheetScreen(
                blur: scenario.blur,
                caret: scenario.caret,
                screenOverlay: RasterGlow(
                  caret: scenario.caret,
                  intensity: scenario.blur ? 1 : .45,
                ),
              ),
            ),
            const SizedBox(width: 80),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GpuWorkFormula(
                    framesPerSecond: scenario.framesPerSecond,
                    passesPerFrame: scenario.passesPerFrame,
                  ),
                  const Spacer(),
                  if (showCaption)
                    Text(
                      scenario.caption,
                      style: archivo(30, height: 1.35, color: p.text),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pane extends StatelessWidget {
  const _Pane({
    required this.label,
    required this.sublabel,
    required this.child,
  });

  final String label;
  final String sublabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SizedBox(
      width: 262,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: archivo(26, weight: 500, color: p.text)),
          const SizedBox(height: 2),
          Text(sublabel.toUpperCase(), style: mono(15, color: p.textTertiary)),
          const SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Flashes over the caret on the frames where its pixels change, like
/// Flutter's "Highlight repaints".
class RepaintFlash extends StatelessWidget {
  const RepaintFlash({required this.caret, super.key});

  final CaretMode caret;

  static final _flash = Track<double>(
    .single,
    initial: 0,
    debugLabel: 'Repaint flash',
  );

  @override
  Widget build(BuildContext context) {
    if (caret == CaretMode.none) return const SizedBox.shrink();
    return TrackBuilder(
      debugLabel: 'Repaint flash',
      loop: .loop,
      animations: [_flash(CaretTiming.repaints(caret))],
      builder: (context, value, child) =>
          Opacity(opacity: value(_flash).clamp(0, 1), child: child),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: heat.withValues(alpha: .25),
          border: Border.all(color: heat, width: 3),
        ),
      ),
    );
  }
}

/// Tints the whole screen on every frame the app renders: continuously while
/// something ticks every vsync, once per frame for a slow timer, never when
/// idle. [intensity] scales the tint with the cost of each frame.
class RasterGlow extends StatelessWidget {
  const RasterGlow({required this.caret, this.intensity = 1, super.key});

  final CaretMode caret;
  final double intensity;

  static final _glow = Track<double>(
    .single,
    initial: 0,
    debugLabel: 'Raster glow',
  );

  static const _flicker = Motion.linear(Duration(milliseconds: 90));

  @override
  Widget build(BuildContext context) {
    final steps = switch (caret) {
      CaretMode.none => const <TrackStep<double>>[.to(0, motion: _flicker)],
      // A frame every vsync: a steady glow with a shimmer, too fast to count.
      CaretMode.fading => const <TrackStep<double>>[
        .to(1, motion: _flicker),
        .to(.8, motion: _flicker),
      ],
      CaretMode.blinking => CaretTiming.repaints(caret),
    };
    return IgnorePointer(
      child: TrackBuilder(
        debugLabel: 'Raster glow',
        loop: caret == CaretMode.none ? .none : .loop,
        animations: [_glow(steps)],
        builder: (context, value, child) => Opacity(
          opacity: (value(_glow) * intensity).clamp(0, 1),
          child: child,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: heat.withValues(alpha: .28),
            border: Border.all(color: heat, width: 6),
          ),
        ),
      ),
    );
  }
}

/// GPU work = how often × how hard, with animated numbers and bars.
class GpuWorkFormula extends StatelessWidget {
  const GpuWorkFormula({
    required this.framesPerSecond,
    required this.passesPerFrame,
    super.key,
  });

  final int framesPerSecond;
  final int passesPerFrame;

  static const _maxFrames = 120;
  static const _maxPasses = 5;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final work = framesPerSecond * passesPerFrame;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Term(
          label: 'How often',
          value: framesPerSecond,
          unit: 'frames / s',
          fraction: framesPerSecond / _maxFrames,
          color: p.accent,
        ),
        const _Operator('×'),
        _Term(
          label: 'How hard',
          value: passesPerFrame,
          prefix: passesPerFrame > 1 ? '≈' : '',
          unit: passesPerFrame > 1
              ? 'render passes / frame (blur)'
              : 'render pass / frame',
          fraction: passesPerFrame / _maxPasses,
          color: p.accent,
        ),
        const _Operator('='),
        _Term(
          label: 'GPU work',
          value: work,
          prefix: passesPerFrame > 1 && work > 0 ? '≈' : '',
          unit: 'passes / s',
          fraction: work / (_maxFrames * _maxPasses),
          color: heat,
        ),
      ],
    );
  }
}

class _Operator extends StatelessWidget {
  const _Operator(this.symbol);

  final String symbol;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(symbol, style: mono(36, color: p.textTertiary)),
    );
  }
}

class _Term extends StatelessWidget {
  const _Term({
    required this.label,
    required this.value,
    required this.unit,
    required this.fraction,
    required this.color,
    this.prefix = '',
  });

  final String label;
  final int value;
  final String prefix;
  final String unit;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return MotionBuilder<(double, double)>(
      value: (value.toDouble(), fraction.clamp(0, 1)),
      motion: const .smoothSpring(),
      converter: _pair,
      builder: (context, animated, child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: mono(18, color: p.textTertiary)),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              SizedBox(
                width: 190,
                child: Text(
                  '$prefix${animated.$1.round()}',
                  style: archivo(64, spacing: -2, color: p.text),
                ),
              ),
              Text(unit, style: archivo(24, color: p.textSecondary)),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 14,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: p.control),
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: animated.$2.clamp(0, 1),
                  child: ColoredBox(color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final MotionConverter<(double, double)> _pair = .custom(
  normalize: (value) => [value.$1, value.$2],
  denormalize: (values) => (values[0], values[1]),
);
