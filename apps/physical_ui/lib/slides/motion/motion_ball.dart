import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:heroine/heroine.dart';
import 'package:motor/motor.dart';

class MotionBall extends HookWidget {
  const MotionBall({
    required this.value,
    required this.target,
    this.diameter = 200,
    super.key,
  });

  final double value;

  final double target;

  final double diameter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Align(
          alignment: Alignment(0, 1 - target * 2),
          child: SizedBox.square(
            dimension: diameter,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: CircleBorder(),
                color: theme.colorScheme.tertiaryContainer,
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment(0, 1 - value * 2),
          child: Heroine(
            tag: true,
            motion: CupertinoMotion.bouncy(),
            child: SizedBox.square(
              dimension: diameter,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  shape: CircleBorder(),
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
