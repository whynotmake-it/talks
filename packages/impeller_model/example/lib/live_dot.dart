/// A "live" indicator that pulses forever: the kind of subtle, endless
/// animation that keeps a static-looking screen rendering.
library;

import 'package:fixed_ticker/fixed_ticker.dart';
import 'package:flutter/widgets.dart';

class LiveDot extends StatefulWidget {
  const LiveDot({super.key, this.fps});

  /// Tick rate. `null` ticks every vsync like a plain `Ticker`.
  final double? fps;

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot>
    with SingleFixedTickerProviderStateMixin {
  @override
  TickerRate get tickerRate => widget.fps == null
      ? const TickerRate.vsync()
      : TickerRate.fps(widget.fps!);

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: 0.3, end: 1).animate(_pulse),
    child: const SizedBox.square(
      dimension: 12,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xFFE53935),
          shape: BoxShape.circle,
        ),
      ),
    ),
  );
}
