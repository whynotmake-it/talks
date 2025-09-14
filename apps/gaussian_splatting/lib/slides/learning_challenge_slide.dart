import 'package:flutter/material.dart';
import 'package:gaussian_splatting/shared/animated_element.dart';
import 'package:wnma_talk/wnma_talk.dart';

class LearningChallengeSlide extends FlutterDeckSlideWidget {
  const LearningChallengeSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/learning-challenge',
          steps: 3,
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
          child: Stack(
            children: [
              Row(
                children: [
                  // LEFT SIDE: Differentiable Rendering
                  Expanded(
                    child: _DifferentiableRenderingSection(
                      theme: theme,
                      colorScheme: colorScheme,
                    ),
                  ),

                  // RIGHT SIDE: Learning AI Image
                  Expanded(
                    child: _LearningImageSection(
                      theme: theme,
                      colorScheme: colorScheme,
                    ),
                  ),
                ],
              ),

              // Fullscreen backpropagation overlay
              if (stepNumber == 2)
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
    required this.colorScheme,
  });

  final FlutterDeckThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(50),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                'How can a machine learn to render?',
                textAlign: TextAlign.left,
              ),
            ),
          ),

          const SizedBox(height: 60),

          // Bullet points
          AnimatedElement(
            visible: true,
            stagger: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BulletPoint(
                  text: 'Optimization based on images',
                  theme: theme,
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: 20),
                _BulletPoint(
                  text: 'Loss is typically the difference between a rendering and a photo',
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
      ),
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedElement(
          visible: true,
          stagger: 2,
          child: Image.asset(
            'assets/learning-ai2.png',
            height: 1000,
          ),
        ),
      ],
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: DefaultTextStyle.merge(
            style: theme.textTheme.bodyMedium.copyWith(
              color: colorScheme.onSurface,
              fontSize: 28,
            ),
            child: Text(
              text,
              textAlign: TextAlign.left,
            ),
          ),
        ),
      ],
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
        color: Colors.black.withValues(alpha: 0.9),
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

