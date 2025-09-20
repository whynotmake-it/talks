import 'package:flutter/material.dart';
import 'package:rivership/rivership.dart';
import 'package:wnma_talk/wnma_talk.dart';

class ForwardInverseGraphicsSlide extends FlutterDeckSlideWidget {
  const ForwardInverseGraphicsSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/forward-inverse-graphics',
          steps: 2,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = FlutterDeckTheme.of(context);
    final colorScheme = theme.materialTheme.colorScheme;

    return FlutterDeckSlide.custom(
      builder: (context) => ColoredBox(
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
                    // LEFT SIDE: Forward Graphics
                    Expanded(
                      child: _ForwardGraphicsSection(
                        theme: theme,
                        colorScheme: colorScheme,
                      ),
                    ),

                    // RIGHT SIDE: Inverse Graphics
                    Expanded(
                      child: _InverseGraphicsSection(
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
    );
  }
}

class _ForwardGraphicsSection extends StatelessWidget {
  const _ForwardGraphicsSection({
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
        _AnimatedElement(
          visible: true,
          stagger: 0,
          child: DefaultTextStyle.merge(
            style: theme.textTheme.header.copyWith(
              color: colorScheme.onSurface,
              fontSize: 48,
            ),
            child: const Text(
              'FORWARD RENDERING',
              textAlign: TextAlign.center,
            ),
          ),
        ),

        const SizedBox(height: 40),

        // 3D Scene
        _AnimatedElement(
          visible: true,
          stagger: 1,
          child: Column(
            children: [
              Image.asset(
                'assets/mesh-banana.png',
                height: 250,
              ),
              const SizedBox(height: 10),
              DefaultTextStyle.merge(
                style: theme.textTheme.bodyMedium.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                child: const Text('3D Scene'),
              ),
            ],
          ),
        ),

        // Arrow down
        _AnimatedElement(
          visible: true,
          stagger: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Icon(
              Icons.arrow_downward,
              size: 60,
              color: colorScheme.primary,
            ),
          ),
        ),

        // Rendered result
        _AnimatedElement(
          visible: true,
          stagger: 3,
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/banana.png',
                  height: 250,
                ),
              ),
              const SizedBox(height: 10),
              DefaultTextStyle.merge(
                style: theme.textTheme.bodyMedium.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                child: const Text('Pixels'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 30),
      ],
    );
  }
}

class _InverseGraphicsSection extends StatelessWidget {
  const _InverseGraphicsSection({
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
            _AnimatedElement(
              visible: stepNumber > 1,
              stagger: 0,
              child: DefaultTextStyle.merge(
                style: theme.textTheme.header.copyWith(
                  color: colorScheme.onSurface,
                  fontSize: 48,
                ),
                child: const Text(
                  'INVERSE RENDERING',
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          const SizedBox(height: 40),

          // Target pixels
          if (stepNumber > 1)
            _AnimatedElement(
              visible: stepNumber > 1,
              stagger: 1,
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/banana.png',
                      height: 250,
                    ),
                  ),
                  const SizedBox(height: 10),
                  DefaultTextStyle.merge(
                    style: theme.textTheme.bodyMedium.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    child: const Text('Target Pixels'),
                  ),
                ],
              ),
            ),

          // Gradient arrows up
          if (stepNumber > 1)
            _AnimatedElement(
              visible: stepNumber > 1,
              stagger: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Icon(
                  Icons.arrow_upward,
                  size: 60,
                  color: colorScheme.primary,
                ),
              ),
            ),

          // Recovered scene
          if (stepNumber > 1)
            _AnimatedElement(
              visible: stepNumber > 1,
              stagger: 3,
              child: Column(
                children: [
                  Image.asset(
                    'assets/mesh-banana.png',
                    height: 250,
                  ),
                  const SizedBox(height: 10),
                  DefaultTextStyle.merge(
                    style: theme.textTheme.bodyMedium.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    child: const Text('Learned Scene'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AnimatedElement extends StatelessWidget {
  const _AnimatedElement({
    required this.visible,
    required this.stagger,
    required this.child,
  });

  final bool visible;
  final int stagger;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = CupertinoMotion.bouncy(
      duration:
          const Duration(milliseconds: 600) +
          Duration(milliseconds: 100 * stagger),
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
