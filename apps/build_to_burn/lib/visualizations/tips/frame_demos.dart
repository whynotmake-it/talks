import 'dart:async';
import 'dart:math' as math;

import 'package:build_to_burn/shared/style.dart';
import 'package:build_to_burn/visualizations/tips/tip_kit.dart';
import 'package:fixed_ticker/fixed_ticker.dart';
import 'package:flutter/widgets.dart';

/// The same spinner at three fixed rates, and a dot grid that only moves in
/// steps anyway.
class TimerSpinnersDemo extends StatelessWidget {
  const TimerSpinnersDemo({super.key});

  @override
  Widget build(BuildContext context) {
    Widget cell(Widget child, int fps) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [child, const SizedBox(height: 28), Fps(fps)],
    );
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            cell(Spinner(rate: TickerRate.fps(60)), 60),
            cell(Spinner(rate: TickerRate.fps(30)), 30),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            cell(Spinner(rate: TickerRate.fps(10)), 10),
            cell(const _DotGrid(), 8),
          ],
        ),
      ],
    );
  }
}

/// An "agent thinking" grid: a wave of lit dots that moves one dot per step,
/// on a ticker at 8 fps — the steps it draws anyway.
class _DotGrid extends StatefulWidget {
  const _DotGrid();

  @override
  State<_DotGrid> createState() => _DotGridState();
}

class _DotGridState extends State<_DotGrid>
    with SingleFixedTickerProviderStateMixin {
  static const _steps = 8;

  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  @override
  TickerRate get tickerRate => TickerRate.fps(_steps.toDouble());

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SizedBox.square(
      dimension: 120,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final step = (_controller.value * _steps).floor();
          return GridView.count(
            crossAxisCount: 3,
            mainAxisSpacing: 18,
            crossAxisSpacing: 18,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < 9; i++)
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(
                      p.control,
                      p.accent,
                      // Diagonal wave: dots on the same diagonal light up
                      // together, then fade over the next steps.
                      math.max(
                        0,
                        1 - ((step - (i ~/ 3 + i % 3)) % _steps) / 3,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// A sheet slides over a screen with a spinner. The spinner keeps running
/// behind the sheet, until its ticker is muted.
class HiddenRouteDemo extends StatelessWidget {
  const HiddenRouteDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Loop(
      period: const Duration(seconds: 9),
      builder: (context, t) {
        final sheet = phase(t, .1, .2) - phase(t, .8, .9);
        final muted = t > .45 && t < .8;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 340,
              height: 560,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: p.canvas,
                border: Border.all(color: p.borderStrong, width: 3),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 90,
                    child: Center(
                      child: TickerMode(
                        enabled: !muted,
                        child: Spinner(rate: TickerRate.fps(60)),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: ColoredBox(
                      color: p.text.withValues(alpha: .18 * sheet),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 320,
                    child: FractionalTranslation(
                      translation: Offset(0, 1 - sheet),
                      child: Container(
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(32),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A caret that fades, drawing every frame, next to one that blinks.
class CaretDemo extends StatelessWidget {
  const CaretDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Field(caret: _FadingCaret()),
        _Field(caret: _BlinkingCaret()),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.caret});

  final Widget caret;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      width: 520,
      height: 110,
      padding: const EdgeInsets.symmetric(horizontal: 36),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: p.canvas,
        border: Border.all(color: p.borderStrong, width: 3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: caret,
    );
  }
}

class _Caret extends StatelessWidget {
  const _Caret({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      width: 6,
      height: 60,
      color: p.accent.withValues(alpha: opacity),
    );
  }
}

/// Fades on every frame, like `cursorOpacityAnimates: true`.
class _FadingCaret extends StatefulWidget {
  const _FadingCaret();

  @override
  State<_FadingCaret> createState() => _FadingCaretState();
}

class _FadingCaretState extends State<_FadingCaret>
    with SingleFixedTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  @override
  TickerRate get tickerRate => TickerRate.fps(60);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => _Caret(
      opacity: .5 + .5 * math.cos(_controller.value * math.pi * 2),
    ),
  );
}

/// Toggles on a timer, like `cursorOpacityAnimates: false`.
class _BlinkingCaret extends StatefulWidget {
  const _BlinkingCaret();

  @override
  State<_BlinkingCaret> createState() => _BlinkingCaretState();
}

class _BlinkingCaretState extends State<_BlinkingCaret> {
  var _on = true;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => setState(() => _on = !_on),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Caret(opacity: _on ? 1 : 0);
}
