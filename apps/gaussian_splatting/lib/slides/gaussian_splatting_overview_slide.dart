import 'package:flutter/material.dart';
import 'package:rivership/rivership.dart';
import 'package:wnma_talk/wnma_talk.dart';

class GaussianSplattingOverviewSlide extends FlutterDeckSlideWidget {
  const GaussianSplattingOverviewSlide({super.key})
      : super(
          configuration: const FlutterDeckSlideConfiguration(
            route: '/gaussian-splatting-overview',
            steps: 1,
          ),
        );

  @override
  Widget build(BuildContext context) {
    final theme = FlutterDeckTheme.of(context);
    final colorScheme = theme.materialTheme.colorScheme;

    return FlutterDeckSlide.custom(
      builder: (context) => FlutterDeckSlideStepsBuilder(
        builder: (context, stepNumber) => ColoredBox(
          color: colorScheme.surface,
          child: Center(
            child: _AnimatedElement(
              visible: stepNumber >= 1,
              child: Image.asset(
                'assets/gs-overview.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedElement extends StatelessWidget {
  const _AnimatedElement({
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = CupertinoMotion.bouncy(
      duration: const Duration(milliseconds: 600),
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