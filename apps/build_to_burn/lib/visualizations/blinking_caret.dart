import 'package:build_to_burn/shared/style.dart';
import 'package:build_to_burn/visualizations/blur_scenario.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// Timings shared by the caret and the overlays that show its frames, so
/// they stay in step. One cycle is one second.
abstract final class CaretTiming {
  static const _fade = Motion.curved(Duration(milliseconds: 100), easeInOut);
  static const _jump = Motion.linear(Duration(milliseconds: 1));

  /// The caret's opacity over one cycle.
  static List<TrackStep<double>> opacity(CaretMode mode) => switch (mode) {
    CaretMode.none => const [],
    CaretMode.fading => const [
      .hold(Duration(milliseconds: 500)),
      .to(0, motion: _fade),
      .hold(Duration(milliseconds: 300)),
      .to(1, motion: _fade),
    ],
    CaretMode.blinking => const [
      .hold(Duration(milliseconds: 499)),
      .to(0, motion: _jump),
      .hold(Duration(milliseconds: 499)),
      .to(1, motion: _jump),
    ],
  };

  /// 1 while the caret's pixels change (the frames that repaint), else 0.
  static List<TrackStep<double>> repaints(CaretMode mode) => switch (mode) {
    CaretMode.none => const [],
    CaretMode.fading => const [
      .hold(Duration(milliseconds: 500)),
      .to(1, motion: _jump),
      .hold(Duration(milliseconds: 98)),
      .to(0, motion: _jump),
      .hold(Duration(milliseconds: 300)),
      .to(1, motion: _jump),
      .hold(Duration(milliseconds: 98)),
      .to(0, motion: _jump),
    ],
    CaretMode.blinking => const [
      .to(1, motion: _jump),
      .hold(Duration(milliseconds: 120)),
      .to(0, motion: _jump),
      .hold(Duration(milliseconds: 378)),
    ],
  };
}

/// A text caret that ticks like a focused text field's in [mode].
class BlinkingCaret extends StatelessWidget {
  const BlinkingCaret({
    this.mode = CaretMode.fading,
    this.height = 64,
    this.width = 6,
    this.color,
    super.key,
  });

  final CaretMode mode;
  final double height;
  final double width;
  final Color? color;

  static final _opacity = Track<double>(
    .single,
    initial: 1,
    debugLabel: 'Caret opacity',
  );

  @override
  Widget build(BuildContext context) {
    if (mode == CaretMode.none) return SizedBox(width: width, height: height);
    final color = this.color ?? Palette.of(context).accent;
    return TrackBuilder(
      debugLabel: 'Blinking caret',
      loop: .loop,
      animations: [_opacity(CaretTiming.opacity(mode))],
      builder: (context, value, child) =>
          Opacity(opacity: value(_opacity).clamp(0, 1), child: child),
      child: SizedBox(
        width: width,
        height: height,
        child: ColoredBox(color: color),
      ),
    );
  }
}
