import 'package:flutter/material.dart';
import 'package:rivership/rivership.dart';

class AnimatedVisibility extends StatelessWidget {
  const AnimatedVisibility({
    required this.child,
    super.key,
    this.visible = true,
    this.animateIn = true,
    this.from = const Offset(0, 20),
    this.scaleFrom = 1.0,
    this.opacityFrom = 0.0,
    this.motion = const CupertinoMotion.smooth(),
    this.stagger = 0,
  });

  final bool visible;

  final int stagger;

  final bool animateIn;

  final Offset from;

  final double scaleFrom;

  final double opacityFrom;

  final CupertinoMotion motion;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final target = visible ? 1.0 : 0.0;
    final from = animateIn ? 0.0 : target;

    final scaleTarget = visible ? 1.0 : this.scaleFrom;
    final scaleFrom = animateIn ? this.scaleFrom : scaleTarget;

    final motion = this.motion.copyWith(
      duration: this.motion.duration + Duration(milliseconds: 100 * stagger),
    );

    return SingleMotionBuilder(
      value: target,
      from: from,
      motion: motion,
      builder: (context, value, child) => Transform.translate(
        offset: this.from * (1 - value),
        child: Opacity(
          opacity: (opacityFrom + (1 - opacityFrom) * value).clamp(0.0, 1.0),
          child: child,
        ),
      ),
      child: SingleMotionBuilder(
        value: scaleTarget,
        motion: motion,
        from: scaleFrom,
        builder: (context, value, child) => Transform.scale(
          scale: value,
          child: child,
        ),
        child: child,
      ),
    );
  }
}
