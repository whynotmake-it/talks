import 'package:flutter/material.dart';
import 'package:wnma_talk/animated_element.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart';

class LearningQuerySlide extends FlutterDeckSlideWidget {
  const LearningQuerySlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/learning-query',
          steps: 2,
          speakerNotes: timSlideNotesHeader,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = FlutterDeckTheme.of(context);
    final colorScheme = theme.materialTheme.colorScheme;

    return FlutterDeckSlide.custom(
      builder: (context) => SlideNumber(
        child: ColoredBox(
          color: colorScheme.surface,
          child: Stack(
            children: [
              // Split divider line
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    width: 2,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
                  ),
                ),
              ),

              FlutterDeckSlideStepsBuilder(
                builder: (context, stepNumber) {
                  return Row(
                    children: [
                      // LEFT SIDE: Learning
                      Expanded(
                        child: _LearningSection(
                          theme: theme,
                          colorScheme: colorScheme,
                        ),
                      ),

                      // RIGHT SIDE: Query
                      Expanded(
                        child: _QuerySection(
                          stepNumber: stepNumber,
                          theme: theme,
                          colorScheme: colorScheme,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LearningSection extends StatelessWidget {
  const _LearningSection({
    required this.theme,
    required this.colorScheme,
  });

  final FlutterDeckThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Title
        AnimatedElement(
          visible: true,
          stagger: 0,
          child: DefaultTextStyle.merge(
            style: theme.textTheme.header.copyWith(
              color: colorScheme.onSurface,
              fontSize: 48,
            ),
            child: const Text(
              'LEARNING',
              textAlign: TextAlign.center,
            ),
          ),
        ),

        const SizedBox(height: 40),

        // Learning image
        AnimatedElement(
          visible: true,
          stagger: 1,
          child: Image.asset(
            'assets/learning-ai.png',
            height: 600,
          ),
        ),

        const SizedBox(height: 30),
      ],
    );
  }
}

class _QuerySection extends StatelessWidget {
  const _QuerySection({
    required this.stepNumber,
    required this.theme,
    required this.colorScheme,
  });

  final int stepNumber;
  final FlutterDeckThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(50),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Title
          if (stepNumber > 1)
            AnimatedElement(
              visible: stepNumber > 1,
              stagger: 0,
              child: DefaultTextStyle.merge(
                style: theme.textTheme.header.copyWith(
                  color: colorScheme.onSurface,
                  fontSize: 48,
                ),
                child: const Text(
                  'QUERY',
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          const SizedBox(height: 40),

          // Query image
          if (stepNumber > 1)
            AnimatedElement(
              visible: stepNumber > 1,
              stagger: 1,
              child: Image.asset(
                'assets/query-ai.png',
                height: 600,
              ),
            ),
        ],
      ),
    );
  }
}
