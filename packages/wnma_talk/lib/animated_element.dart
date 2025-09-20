import 'package:flutter/material.dart';
import 'package:rivership/rivership.dart';

class AnimatedElement extends StatelessWidget {
  const AnimatedElement({
    required this.visible,
    required this.stagger,
    required this.child,
    super.key,
  });

  final bool visible;
  final int stagger;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = CupertinoMotion.bouncy(
      duration:
          const Duration(milliseconds: 600) +
          Duration(milliseconds: 100 * stagger),
    );

    return MotionBuilder(
      value: visible ? Offset.zero : const Offset(0, 50),
      motion: motion,
      converter: OffsetMotionConverter(),
      builder: (context, value, child) => Transform.translate(
        offset: value,
        child: SingleMotionBuilder(
          value: visible ? 1.0 : 0.0,
          motion: motion,
          child: child,
          builder: (context, value, child) => Transform.scale(
            scale: 0.8 + (0.2 * value),
            child: Opacity(
              opacity: value.clamp(0, 1),
              child: child,
            ),
          ),
        ),
      ),
      child: child,
    );
  }
}
