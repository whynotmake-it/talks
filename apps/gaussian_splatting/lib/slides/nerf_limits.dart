import 'package:flutter/material.dart';
import 'package:rivership/rivership.dart';
import 'package:wnma_talk/wnma_talk.dart';

class NerfLimitsSlide extends FlutterDeckSlideWidget {
  const NerfLimitsSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/nerf-limits',
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
          padding: const EdgeInsets.all(50),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
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
                    'What limits the rendering speed?',
                    textAlign: TextAlign.left,
                  ),
                ),
              ),

              const SizedBox(height: 80),

              // Bullet points
              _AnimatedElement(
                visible: true,
                stagger: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BulletPoint(
                      text: 'Decode radiance field from neural representation',
                      theme: theme,
                      colorScheme: colorScheme,
                    ),
                    const SizedBox(height: 40),
                    _BulletPoint(
                      text: 'Volume rendering which both need to be done for too many samples along each ray',
                      theme: theme,
                      colorScheme: colorScheme,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
              fontSize: 32,
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