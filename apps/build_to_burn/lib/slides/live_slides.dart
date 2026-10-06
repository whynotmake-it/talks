import 'dart:math' as math;

import 'package:build_to_burn/shared/slide_frame.dart';
import 'package:build_to_burn/shared/style.dart';
import 'package:build_to_burn/visualizations/gpu_frame.dart';
import 'package:flutter/material.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart';

/// The live demo: the phone and Xcode's Energy Impact gauge, run on stage.
/// The slide only marks the switch; it will hold the backup video.
class LiveSlide extends FlutterDeckSlideWidget {
  const LiveSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/live',
          title: 'Live demo',
          speakerNotes: jesperSlideNotesHeader,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) {
        final p = Palette.of(context);
        return SlideFrame(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: heat,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 40),
                Text('LIVE', style: p.hero),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// After the demo: the GPU chapter's round trip, now on every frame, then
/// the heat it makes.
class EveryFrameSlide extends FlutterDeckSlideWidget {
  const EveryFrameSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/every-frame',
          title: 'Every frame',
          steps: 2,
          speakerNotes: jesperSlideNotesHeader,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => SlideFrame(
        padding: const EdgeInsets.fromLTRB(80, 0, 80, 24),
        child: FlutterDeckSlideStepsBuilder(
          builder: (context, step) {
            final p = Palette.of(context);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 80,
                  child: Text(
                    'Every frame',
                    style: archivo(48, weight: 500, color: p.text),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      const Positioned.fill(
                        child: GpuFrame(beat: GpuBeat.repeat),
                      ),
                      if (step >= 2)
                        const Align(
                          alignment: Alignment(-.42, .55),
                          child: _Flame(),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A flame that grows in, then flickers.
class _Flame extends StatefulWidget {
  const _Flame();

  @override
  State<_Flame> createState() => _FlameState();
}

class _FlameState extends State<_Flame> with SingleTickerProviderStateMixin {
  late final _flicker = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _flicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: easeOut,
      builder: (context, grow, _) => AnimatedBuilder(
        animation: _flicker,
        builder: (context, _) => Transform.scale(
          scale: grow * (1 + .06 * _flicker.value),
          alignment: Alignment.bottomCenter,
          child: Opacity(
            opacity: grow,
            child: const Icon(
              Icons.local_fire_department,
              size: 320,
              color: heat,
            ),
          ),
        ),
      ),
    );
  }
}

/// The zoom out: DevTools sees every frame on time; the energy gauge sees
/// what they cost.
///
/// The frame chart is drawn, not a screenshot yet: many short bars under
/// the 120 Hz budget, as the focused caret produces them.
class FastNotCheapSlide extends FlutterDeckSlideWidget {
  const FastNotCheapSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/fast-not-cheap',
          title: 'Fast is not cheap',
          speakerNotes: jesperSlideNotesHeader,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) {
        final p = Palette.of(context);
        return SlideFrame(
          padding: const EdgeInsets.fromLTRB(80, 0, 80, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 80,
                child: Text(
                  'Fast is not the same as cheap',
                  style: archivo(48, weight: 500, color: p.text),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _Panel(
                        label: 'DEVTOOLS · IS IT FAST?',
                        answer: 'Yes',
                        answerColor: const Color(0xFF2CA02C),
                        child: CustomPaint(
                          painter: _FrameChartPainter(p: p),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                    const SizedBox(width: 60),
                    Expanded(
                      child: _Panel(
                        label: 'ENERGY IMPACT · IS IT CHEAP?',
                        answer: 'No',
                        answerColor: heat,
                        child: CustomPaint(
                          painter: _GaugePainter(p: p, needle: .62),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.label,
    required this.answer,
    required this.answerColor,
    required this.child,
  });

  final String label;
  final String answer;
  final Color answerColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Stage(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: mono(28, weight: 700, color: p.textTertiary)),
            const SizedBox(height: 24),
            Expanded(child: child),
            const SizedBox(height: 24),
            Text(
              answer,
              style: archivo(72, weight: 700, color: answerColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// A DevTools-like frame chart: one short bar per frame, all well under the
/// dashed 120 Hz budget.
class _FrameChartPainter extends CustomPainter {
  _FrameChartPainter({required this.p});

  final Palette p;

  @override
  void paint(Canvas canvas, Size size) {
    const frames = 60;
    final budgetY = size.height * .3;
    final step = size.width / frames;
    final random = math.Random(4);
    final bar = Paint()..color = const Color(0xFF2CA02C);
    for (var i = 0; i < frames; i++) {
      final h = size.height * (.05 + .06 * random.nextDouble());
      canvas.drawRect(
        Rect.fromLTWH(i * step + 1, size.height - h, step - 3, h),
        bar,
      );
    }
    final dash = Paint()
      ..color = p.textSecondary
      ..strokeWidth = 3;
    for (var x = 0.0; x < size.width; x += 24) {
      canvas.drawLine(
        Offset(x, budgetY),
        Offset(math.min(x + 12, size.width), budgetY),
        dash,
      );
    }
    TextPainter(
        text: TextSpan(
          text: '8.3 ms · 120 Hz budget',
          style: mono(24, color: p.textSecondary),
        ),
        textDirection: TextDirection.ltr,
      )
      ..layout()
      ..paint(canvas, Offset(0, budgetY - 36))
      ..dispose();
  }

  @override
  bool shouldRepaint(_FrameChartPainter old) => p != old.p;
}

/// Xcode's Energy Impact gauge, simplified: green low, yellow high, red very
/// high, and a needle at [needle] (0..1 across the arc).
class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.p, required this.needle});

  final Palette p;
  final double needle;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(size.width / 2, size.height) * .9;
    final center = Offset(size.width / 2, size.height * .5 + radius / 2);
    final arc = Rect.fromCircle(center: center, radius: radius);
    const zones = [
      (0.0, .45, Color(0xFF2CA02C)),
      (.45, .8, Color(0xFFF2C12E)),
      (.8, 1.0, heat),
    ];
    for (final (from, to, color) in zones) {
      canvas.drawArc(
        arc,
        math.pi + from * math.pi,
        (to - from) * math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 44
          ..color = color,
      );
    }
    final angle = math.pi + needle * math.pi;
    canvas
      ..drawLine(
        center,
        center + Offset(math.cos(angle), math.sin(angle)) * radius * .85,
        Paint()
          ..color = p.text
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round,
      )
      ..drawCircle(center, 18, Paint()..color = p.text);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => p != old.p || needle != old.needle;
}
