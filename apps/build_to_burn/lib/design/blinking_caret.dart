import 'package:build_to_burn/design/style.dart';
import 'package:flutter/widgets.dart';
import 'package:motor/motor.dart';

/// A text caret that blinks forever, like a focused text field's.
///
/// This is the talk's hook: while it is on screen, the engine produces a new
/// frame every vsync.
class BlinkingCaret extends StatelessWidget {
  const BlinkingCaret({
    this.height = 64,
    this.width = 6,
    this.color,
    super.key,
  });

  final double height;
  final double width;
  final Color? color;

  static final _opacity = Track<double>(
    .single,
    initial: 1,
    debugLabel: 'Caret opacity',
  );

  static const _fade = Motion.curved(Duration(milliseconds: 120), easeInOut);

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? Palette.of(context).accent;
    return TrackBuilder(
      debugLabel: 'Blinking caret',
      loop: .loop,
      animations: [
        _opacity(const [
          .hold(Duration(milliseconds: 500)),
          .to(0, motion: _fade),
          .hold(Duration(milliseconds: 380)),
          .to(1, motion: _fade),
        ]),
      ],
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
