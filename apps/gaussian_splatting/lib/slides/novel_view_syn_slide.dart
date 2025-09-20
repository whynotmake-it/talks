import 'package:flutter/material.dart';
import 'package:rivership/rivership.dart';
import 'package:wnma_talk/animated_element.dart';
import 'package:wnma_talk/wnma_talk.dart';

class NovelViewSynSlide extends FlutterDeckSlideWidget {
  const NovelViewSynSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/novel-view-syn',
          steps: 7,
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
            // Background: Central banana (always visible)
            Align(
              alignment: Alignment(0,-5),
              child: Image.asset(
                'assets/banana.png',
          
              ),
            ),

            // Title
            // Positioned(
            //   top: 50,
            //   left: 100,
            //   child: DefaultTextStyle.merge(
            //     style: theme.textTheme.display.copyWith(
            //       color: colorScheme.onPrimaryContainer,
            //       letterSpacing: -5,
            //       height: 1,
            //     ),
            //     child: const Text('The Challenge: Novel View Synthesis'),
            //   ),
            // ),

            // Animated cameras and previews
            FlutterDeckSlideStepsBuilder(
              builder: (context, stepNumber) {
                return Stack(
                  children: [
                    // Step 0: Top left camera + back banana
                    _AnimatedCameraPair(
                      visible: stepNumber >= 2,
                      stagger: 0,
                      cameraAsset: 'assets/top-left-cam.png',
                      cameraPosition: const Offset(-350, -320),
                      previewAsset: 'assets/back-banana.png',
                      previewIndex: 0,
                    ),

                    // Step 1: Top right camera + right banana
                    _AnimatedCameraPair(
                      visible: stepNumber >= 3,
                      stagger: 1,
                      cameraAsset: 'assets/top-right-cam.png',
                      cameraPosition: const Offset(350, -320),
                      previewAsset: 'assets/right-banana.png',
                      previewIndex: 1,
                    ),

                    // Step 2: Bottom right camera + front banana
                    _AnimatedCameraPair(
                      visible: stepNumber >= 4,
                      stagger: 2,
                      cameraAsset: 'assets/right-bottom-cam.png',
                      cameraPosition: const Offset(350, 100),
                      previewAsset: 'assets/front-banana.png',
                      previewIndex: 2,
                    ),

                    // Step 3: Bottom left camera + left banana
                    _AnimatedCameraPair(
                      visible: stepNumber >= 5,
                      stagger: 3,
                      cameraAsset: 'assets/left-bottom-cam.png',
                      cameraPosition: const Offset(-350, 100),
                      previewAsset: 'assets/left-banana.png',
                      previewIndex: 3,
                    ),

                    // Step 4: New camera top center + blur banana
                    _AnimatedCameraPair(
                      visible: stepNumber >= 6,
                      stagger: 4,
                      cameraAsset: 'assets/new-cam.png',
                      cameraPosition: const Offset(0, -360),
                      previewAsset: 'assets/blur-banana.png',
                      previewIndex: 4,
                    ),

                    // Final step: Full-screen text overlay
                    if (stepNumber >= 7)
                      _NovelViewSynthesisOverlay(
                        theme: theme,
                        colorScheme: colorScheme,
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

class _AnimatedCameraPair extends StatelessWidget {
  const _AnimatedCameraPair({
    required this.visible,
    required this.stagger,
    required this.cameraAsset,
    required this.cameraPosition,
    required this.previewAsset,
    required this.previewIndex,
  });

  final bool visible;
  final int stagger;
  final String cameraAsset;
  final Offset cameraPosition;
  final String previewAsset;
  final int previewIndex;

  @override
  Widget build(BuildContext context) {
    final motion = CupertinoMotion.bouncy(
      duration:
          const Duration(milliseconds: 600) +
          Duration(milliseconds: 100 * stagger),
    );

    return Stack(
      children: [
        // Camera
        Center(
          child: MotionBuilder(
            value: visible ? cameraPosition : cameraPosition * 3,
            motion: motion,
            converter: OffsetMotionConverter(),
            builder: (context, value, child) => Transform.translate(
              offset: value,
              child: SingleMotionBuilder(
                value: visible ? 1.0 : 0.0,
                motion: motion,
                child: child,
                builder: (context, value, child) => Transform.scale(
                  scale: value,
                  child: child,
                ),
              ),
            ),
            child: Image.asset(
              cameraAsset,
              scale: 1.6,
            ),
          ),
        ),

        // Preview at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Center(
            child: MotionBuilder(
              value: visible
                  ? Offset((previewIndex - 2.0) * 320, 0)
                  : Offset((previewIndex - 2.0) * 320, 200),
              motion: motion,
              converter: OffsetMotionConverter(),
              builder: (context, value, child) => Transform.translate(
                offset: value,
                child: SingleMotionBuilder(
                  value: visible ? 1.0 : 0.0,
                  motion: motion,
                  child: child,
                  builder: (context, value, child) => Transform.scale(
                    scale: value,
                    child: Opacity(
                      opacity: value.clamp(0, 1),
                      child: child,
                    ),
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  previewAsset,
                  width: 300,
               
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NovelViewSynthesisOverlay extends StatelessWidget {
  const _NovelViewSynthesisOverlay({
    required this.theme,
    required this.colorScheme,
  });

  final FlutterDeckThemeData theme;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: colorScheme.surface.withValues(alpha: 0.95),
        child: Center(
          child: AnimatedElement(
            visible: true,
            stagger: 0,
            child: DefaultTextStyle.merge(
              style: theme.textTheme.header.copyWith(
                color: colorScheme.onSurface,
                fontSize: 72,
                fontWeight: FontWeight.bold,
              ),
              child: const Text(
                'NOVEL VIEW SYNTHESIS',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}


