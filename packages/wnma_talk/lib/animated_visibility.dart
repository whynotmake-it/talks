import 'package:flutter/material.dart';
import 'package:rivership/rivership.dart';

class AnimatedVisibility extends StatelessWidget {
  const AnimatedVisibility({
    required this.child,
    super.key,
    this.visible = true,
    this.animateIn = true,
    this.from = const Offset(0, 20),
  });

  final bool visible;

  final bool animateIn;

  final Offset from;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final target = visible ? 1.0 : 0.0;
    final from = animateIn ? 0.0 : target;
    return SingleMotionBuilder(
      value: target,
      from: from,
      motion: const CupertinoMotion.smooth(),
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, (1 - value) * 20),
        child: Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
