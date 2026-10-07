import 'dart:math' as math;

import 'package:build_to_burn/shared/style.dart';
import 'package:fixed_ticker/fixed_ticker.dart';
import 'package:flutter/widgets.dart';

// The shared vocabulary of the tip demos: a dashed outline is an offscreen
// layer, a row of bars is render passes, and a small label is a frame rate.
// Everything else is abstract shapes.

/// Repeats a timeline of [period] and builds the demo at its progress `t`,
/// from 0 to 1.
class Loop extends StatefulWidget {
  const Loop({required this.period, required this.builder, super.key});

  final Duration period;
  final Widget Function(BuildContext context, double t) builder;

  @override
  State<Loop> createState() => _LoopState();
}

class _LoopState extends State<Loop> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) => widget.builder(context, _controller.value),
  );
}

/// 0 before [start], 1 after [end], eased in between.
double phase(double t, double start, double end) =>
    easeInOut.transform(((t - start) / (end - start)).clamp(0, 1));

/// A frame rate label.
class Fps extends StatelessWidget {
  const Fps(this.fps, {super.key});

  final int fps;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Text(
      '$fps fps',
      style: mono(30, weight: 500, color: p.textSecondary),
    );
  }
}

/// A spinning arc whose ticker runs at [rate].
class Spinner extends StatefulWidget {
  const Spinner({
    this.rate = const TickerRate.vsync(),
    this.size = 120,
    super.key,
  });

  final TickerRate rate;
  final double size;

  @override
  State<Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<Spinner>
    with SingleFixedTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  TickerRate get tickerRate => widget.rate;

  @override
  void didUpdateWidget(Spinner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rate != widget.rate) updateTickerRate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _ArcPainter(
            turn: _controller.value,
            color: p.accent,
            track: p.control,
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  const _ArcPainter({
    required this.turn,
    required this.color,
    required this.track,
  });

  final double turn;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * .1;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawArc(rect, 0, math.pi * 2, false, paint..color = track)
      ..drawArc(
        rect,
        turn * math.pi * 2 - math.pi / 2,
        math.pi * 1.3,
        false,
        paint..color = color,
      );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.turn != turn || old.color != color || old.track != track;
}

/// A dashed outline around [child]: an offscreen layer.
class LayerOutline extends StatelessWidget {
  const LayerOutline({
    required this.child,
    this.visible = true,
    this.inset = 16,
    super.key,
  });

  final Widget child;
  final bool visible;

  /// How far the outline sits outside [child].
  final double inset;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashPainter(
        color: heat.withValues(alpha: visible ? 1 : 0),
        inset: inset,
      ),
      child: child,
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter({required this.color, required this.inset});

  final Color color;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    if (color.a == 0) return;
    dashedRect(canvas, (Offset.zero & size).inflate(inset), color);
  }

  @override
  bool shouldRepaint(_DashPainter old) =>
      old.color != color || old.inset != inset;
}

/// Strokes [rect] with dashes.
void dashedRect(Canvas canvas, Rect rect, Color color) {
  const dash = 18.0;
  const gap = 12.0;
  final paint = Paint()
    ..color = color
    ..strokeWidth = 4
    ..style = PaintingStyle.stroke;
  final metrics = (Path()..addRect(rect)).computeMetrics();
  for (final metric in metrics) {
    for (var d = 0.0; d < metric.length; d += dash + gap) {
      canvas.drawPath(metric.extractPath(d, d + dash), paint);
    }
  }
}

/// A row of [count] bars, one per render pass.
class PassBars extends StatelessWidget {
  const PassBars({required this.count, this.slots, super.key});

  final int count;

  /// How many bar slots to reserve, so rows line up. Defaults to [count].
  final int? slots;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < (slots ?? count); i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: easeOut,
            width: 14,
            height: 56,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            color: i < count ? heat : p.control,
          ),
      ],
    );
  }
}

/// Diagonal stripes, a background that is not one solid color.
class Stripes extends StatelessWidget {
  const Stripes({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return CustomPaint(
      painter: _StripesPainter(a: p.surface, b: p.accentSoft),
      child: const SizedBox.expand(),
    );
  }
}

class _StripesPainter extends CustomPainter {
  const _StripesPainter({required this.a, required this.b});

  final Color a;
  final Color b;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..clipRect(Offset.zero & size)
      ..drawColor(a, BlendMode.src);
    final paint = Paint()
      ..color = b
      ..strokeWidth = 28;
    for (var x = -size.height; x < size.width; x += 64) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StripesPainter old) => old.a != a || old.b != b;
}

/// An abstract card: a circle and two lines of "text".
class AbstractCard extends StatelessWidget {
  const AbstractCard({super.key});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final fill = p.accent;
    return Container(
      width: 260,
      height: 120,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: p.accentSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 14, color: fill),
                const SizedBox(height: 14),
                FractionallySizedBox(
                  widthFactor: .6,
                  child: Container(height: 14, color: fill),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
