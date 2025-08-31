import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:rivership/rivership.dart';

class MotionBall extends HookWidget {
  const MotionBall({
    required this.value,
    required this.target,
    this.showTarget = true,
    this.diameter = 200,
    super.key,
  });

  final double value;

  final double target;

  final bool showTarget;

  final double diameter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        AnimatedSizeSwitcher(
          child: Align(
            widthFactor: 1,
            key: ValueKey(Object.hash(showTarget, target)),
            alignment: Alignment(0, 1 - target * 2),
            child: showTarget
                ? SizedBox.square(
                    dimension: diameter,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        shape: CircleBorder(),
                        color: theme.colorScheme.tertiaryContainer,
                      ),
                    ),
                  )
                : null,
          ),
        ),
        Align(
          widthFactor: 1,
          alignment: Alignment(0, 1 - value * 2),
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
      ],
    );
  }
}
