import 'package:flutter/material.dart';
import 'package:rivership/rivership.dart';
import 'package:wnma_talk/wnma_talk.dart';

class NerfSlide extends FlutterDeckSlideWidget {
  const NerfSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/nerf',
          steps: 1,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = FlutterDeckTheme.of(context);
    final colorScheme = theme.materialTheme.colorScheme;

    return FlutterDeckSlide.custom(
      builder: (context) => ColoredBox(
        color: colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Title
              _AnimatedElement(
                visible: true,
                stagger: 0,
                child: DefaultTextStyle.merge(
                  style: theme.textTheme.header.copyWith(
                    color: colorScheme.onSurface,
                    fontSize: 56,
                  ),
                  child: const Text(
                    'NEURAL RADIANCE FIELDS',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Images in column
              _AnimatedElement(
                visible: true,
                stagger: 1,
                child: Column(
                  children: [
                    Image.asset(
                      'assets/nerf1.png',
                      height: 400,
                    ),
    
                    Image.asset(
                      'assets/nerf2.png',
                      height: 300,
                    ),
                  ],
                ),
              ),
                    const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(
                    'Storage: ~2 MB',
                    style: theme.textTheme.bodyLarge.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                       Text(
                    'Implicit Representation',
                    style: theme.textTheme.bodyLarge.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                             Text(
                    'Really slow to render',
                    style: theme.textTheme.bodyLarge.copyWith(
                      color: colorScheme.error,
                    ),
                  )
                ],
              ),

              const SizedBox(height: 60),

              // Citation
              _AnimatedElement(
                visible: true,
                stagger: 2,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DefaultTextStyle.merge(
                    style: theme.textTheme.bodyMedium.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                    ),
                    child: const Text(
                      'Mildenhall, B., Srinivasan, P. P., Tancik, M., Barron, J. T., Ramamoorthi, R., & Ng, R. (2021). Nerf: Representing scenes as neural radiance fields for view synthesis. Communications of the ACM, 65(1), 99-106.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
