import 'package:flutter/material.dart';
import 'package:wnma_talk/animated_element.dart';
import 'package:wnma_talk/animated_visibility.dart';
import 'package:wnma_talk/content_slide_template.dart';
import 'package:wnma_talk/wnma_talk.dart';

class LearningChallengeSlide extends FlutterDeckSlideWidget {
  const LearningChallengeSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/learning-challenge',
          steps: 4,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = FlutterDeckTheme.of(context);
    final colorScheme = theme.materialTheme.colorScheme;

    return ContentSlideTemplate(
      title: const Text(
        'How can a machine learn to render?',
        textAlign: TextAlign.left,
      ),
      secondaryContent: _LearningImageSection(
        theme: theme,
        colorScheme: colorScheme,
      ),
      mainContent: FlutterDeckSlideStepsBuilder(
        builder: (context, stepNumber) => ColoredBox(
          color: colorScheme.surface,
          child: Stack(
            children: [
              Row(
                children: [
                  // LEFT SIDE: Differentiable Rendering
                  Expanded(
                    child: _DifferentiableRenderingSection(
                      theme: theme,
                      colorScheme: colorScheme,
                      step: stepNumber,
                    ),
                  ),
                ],
              ),

              if (stepNumber == 2)
                _GradientDescentOverlay(
                  theme: theme,
                  colorScheme: colorScheme,
                ),

              // Fullscreen backpropagation overlay
              if (stepNumber == 3)
                _BackpropagationOverlay(
                  theme: theme,
                  colorScheme: colorScheme,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DifferentiableRenderingSection extends StatelessWidget {
  const _DifferentiableRenderingSection({
    required this.theme,
    required this.step,
    required this.colorScheme,
  });

  final FlutterDeckThemeData theme;
  final int step;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 60),

        // Bullet points
        AnimatedElement(
          visible: true,
          stagger: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedVisibility(
                child: _BulletPoint(
                  text: 'Optimization based on images',
                  theme: theme,
                  colorScheme: colorScheme,
                ),
              ),
              const SizedBox(height: 20),
              _BulletPoint(
                text:
                    'Loss is typically the difference between a rendering and a photo',
                theme: theme,
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 20),
              _BulletPoint(
                text: 'Most rendering algorithms are not differentiable',
                theme: theme,
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 15),
              Padding(
                padding: const EdgeInsets.only(left: 40),
                child: DefaultTextStyle.merge(
                  style: theme.textTheme.bodyMedium.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 24,
                  ),
                  child: const Text(
                    'meshes have hard edges, giving abrupt discontinuities',
                    textAlign: TextAlign.left,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LearningImageSection extends StatelessWidget {
  const _LearningImageSection({
    required this.theme,
    required this.colorScheme,
  });

  final FlutterDeckThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/learning-ai2.png',
      height: 1000,
    );
  }
}

class _BulletPoint extends StatelessWidget {
  const _BulletPoint({
    required this.text,
    required this.theme,
    required this.colorScheme,
  });

  final String text;
  final FlutterDeckThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 600,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: DefaultTextStyle.merge(
              style: theme.textTheme.bodyLarge.copyWith(
                color: colorScheme.onSurface,
              ),
              child: Text(
                text,
                textAlign: TextAlign.left,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackpropagationOverlay extends StatelessWidget {
  const _BackpropagationOverlay({
    required this.theme,
    required this.colorScheme,
  });

  final FlutterDeckThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: Center(
          child: AnimatedElement(
            visible: true,
            stagger: 0,
            child: Image.asset(
              'assets/backpropagation.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientDescentOverlay extends StatelessWidget {
  const _GradientDescentOverlay({
    required this.theme,
    required this.colorScheme,
  });

  final FlutterDeckThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: Center(
          child: AnimatedElement(
            visible: true,
            stagger: 0,
            child: Image.asset(
              'assets/gradient_descent.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
