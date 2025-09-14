import 'package:flutter/material.dart';
import 'package:gaussian_splatting/shared/animated_element.dart';
import 'package:wnma_talk/wnma_talk.dart';

class GaussianSplattingOverviewSlide extends FlutterDeckSlideWidget {
  const GaussianSplattingOverviewSlide({super.key})
      : super(
          configuration: const FlutterDeckSlideConfiguration(
            route: '/gaussian-splatting-overview',
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
            child: AnimatedElement(
              visible: stepNumber >= 1,
              stagger: 0,
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

