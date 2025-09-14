import 'package:flutter/material.dart';
import 'package:gaussian_splatting/shared/animated_element.dart';
import 'package:gaussian_splatting/shared/citation_container.dart';
import 'package:wnma_talk/wnma_talk.dart';

class GaussianSplattingSlide extends FlutterDeckSlideWidget {
  const GaussianSplattingSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/gaussian-splatting',
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
                      '3D GAUSSIAN SPLATTING',
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
                    citation: 'Kerbl, B., Kopanas, G., Leimkühler, T., & Drettakis, G. (2023). 3D Gaussian splatting for real-time radiance field rendering. ACM Trans. Graph., 42(4), 139-1.',
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
            visible: stepNumber >= 3,
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
            visible: stepNumber >= 3,
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
      children: [
        // Ellipsoid image (step 2)
        Expanded(
          flex: 2,
          child: AnimatedElement(
            visible: stepNumber >= 2,
            stagger: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/elipsoid.png',
                  height: 150,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
        ),

        // Bracket and properties (step 2)
        Expanded(
          flex: 3,
          child: AnimatedElement(
            visible: stepNumber >= 2,
            stagger: 2,
            child: Row(
              children: [
                // Bracket
                SizedBox(
                  width: 40,
                  height: 200,
                  child: CustomPaint(
                    painter: _BracketPainter(colorScheme.onSurface),
                  ),
                ),

                const SizedBox(width: 20),

                // Properties column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _PropertyItem(
                        number: '1.',
                        property: 'xyz → position',
                        theme: theme,
                        colorScheme: colorScheme,
                      ),
                      const SizedBox(height: 12),
                      _PropertyItem(
                        number: '2.',
                        property: 'rotation',
                        theme: theme,
                        colorScheme: colorScheme,
                      ),
                      const SizedBox(height: 12),
                      _PropertyItem(
                        number: '3.',
                        property: 'scale',
                        theme: theme,
                        colorScheme: colorScheme,
                      ),
                      const SizedBox(height: 12),
                      _PropertyItem(
                        number: '4.',
                        property: 'opacity',
                        theme: theme,
                        colorScheme: colorScheme,
                      ),
                      const SizedBox(height: 12),
                      _PropertyItem(
                        number: '5.',
                        property: 'color',
                        theme: theme,
                        colorScheme: colorScheme,
                      ),
                    ],
                  ),
                ),
                Text(
                  'Larger files, but fast reendering - Explicit representation',
                  style: theme.textTheme.bodyMedium.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PropertyItem extends StatelessWidget {
  const _PropertyItem({
    required this.number,
    required this.property,
    required this.theme,
    required this.colorScheme,
  });

  final String number;
  final String property;
  final FlutterDeckThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          number,
          style: theme.textTheme.bodyMedium.copyWith(
            color: colorScheme.primary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          property,
          style: theme.textTheme.bodyMedium.copyWith(
            color: colorScheme.onSurface,
            fontSize: 24,
          ),
        ),
      ],
    );
  }
}

class _BracketPainter extends CustomPainter {
  const _BracketPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path()

    // Left bracket shape
    ..moveTo(size.width * 0.8, 0)
    ..lineTo(0, 0)
    ..lineTo(0, size.height)
    ..lineTo(size.width * 0.8, size.height);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


