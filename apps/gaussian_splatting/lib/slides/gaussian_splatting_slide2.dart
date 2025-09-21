import 'package:flutter/material.dart';
import 'package:gaussian_splatting/shared/citation_container.dart';
import 'package:wnma_talk/animated_element.dart';
import 'package:wnma_talk/wnma_talk.dart';

class GaussianSplattingSlide2 extends FlutterDeckSlideWidget {
  const GaussianSplattingSlide2({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/gaussian-splatting2',
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
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                // Title
                AnimatedElement(
                  visible: stepNumber >= 1,
                  stagger: 0,
                  child: DefaultTextStyle.merge(
                    style: theme.textTheme.header.copyWith(
                      color: colorScheme.onSurface,
                      fontSize: 56,
                    ),
                    child: const Text(
                      '3D Gaussian Splatting',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // First row: splat_banana -> rasterizer -> banana
                Expanded(
                  flex: 4,
                  child: _FirstRow(
                    theme: theme,
                    colorScheme: colorScheme,
                    stepNumber: stepNumber,
                  ),
                ),

                // Second row: ellipsoid and properties
                Expanded(
                  flex: 2,
                  child: _SecondRow(
                    theme: theme,
                    colorScheme: colorScheme,
                    stepNumber: stepNumber,
                  ),
                ),

                const SizedBox(height: 16),

                // Citation
                AnimatedElement(
                  visible: stepNumber >= 1,
                  stagger: 4,
                  child: const CitationContainer(
                    citation:
                        'Kerbl, B., Kopanas, G., Leimkühler, T., & Drettakis, G. (2023). 3D Gaussian splatting for real-time radiance field rendering. ACM Trans. Graph., 42(4), 139-1.',
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FirstRow extends StatelessWidget {
  const _FirstRow({
    required this.theme,
    required this.colorScheme,
    required this.stepNumber,
  });

  final FlutterDeckThemeData theme;
  final ColorScheme colorScheme;
  final int stepNumber;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Splat banana (step 1)
        Expanded(
          child: AnimatedElement(
            visible: stepNumber >= 1,
            stagger: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/splat_banana.png',
                  height: 550,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
        ),

        // Arrow and rasterizer label (step 3)
        Expanded(
          child: AnimatedElement(
            visible: stepNumber >= 2,
            stagger: 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.arrow_forward,
                  size: 40,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.primary),
                  ),
                  child: Text(
                    'RASTERIZER',
                    style: theme.textTheme.bodyMedium.copyWith(
                      color: colorScheme.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Icon(
                  Icons.arrow_forward,
                  size: 40,
                  color: colorScheme.primary,
                ),
              ],
            ),
          ),
        ),

        // Final banana (step 3)
        Expanded(
          child: AnimatedElement(
            visible: stepNumber >= 2,
            stagger: 3,
            child: Transform.scale(
              scale: 1.8,
              child: Image.asset(
                'assets/banana.png',
                fit: BoxFit.fitHeight,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SecondRow extends StatelessWidget {
  const _SecondRow({
    required this.theme,
    required this.colorScheme,
    required this.stepNumber,
  });

  final FlutterDeckThemeData theme;
  final ColorScheme colorScheme;
  final int stepNumber;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [

        AnimatedElement(
          visible: stepNumber >= 3,
          stagger: 0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text(
                'Storage: ~20 MB',
                style: theme.textTheme.bodyLarge.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                'Explicit Representation',
                style: theme.textTheme.bodyLarge.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                'Fast to render',
                style: theme.textTheme.bodyLarge.copyWith(
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
