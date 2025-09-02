import 'package:flutter/material.dart';
import 'package:rivership/rivership.dart';
import 'package:wnma_talk/wnma_talk.dart';

class ClassicRenderingSlide extends FlutterDeckSlideWidget {
  const ClassicRenderingSlide({super.key})
      : super(
          configuration: const FlutterDeckSlideConfiguration(
            route: '/classic-rendering',
            steps: 4,
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
            // Background: Final banana (always visible like novel view syn)
            Align(
              alignment: Alignment(0, -5),
              child: Image.asset(
                'assets/mesh-banana.png',
              ),
            ),

            // Title (commented out following novel view syn pattern)
            // Positioned(
            //   top: 50,
            //   left: 100,
            //   child: DefaultTextStyle.merge(
            //     style: theme.textTheme.display.copyWith(
            //       color: colorScheme.onPrimaryContainer,
            //       letterSpacing: -5,
            //       height: 1,
            //     ),
            //     child: ConstrainedBox(
            //       constraints: const BoxConstraints(maxWidth: 800),
            //       child: const Text('Classic Rendering Pipeline'),
            //     ),
            //   ),
            // ),

            // Animated rendering pipeline
            FlutterDeckSlideStepsBuilder(
              builder: (context, stepNumber) {
                return Stack(
                  children: [
                    // Step 2: Texture appears next to mesh
                    _AnimatedRenderingElement(
                      visible: stepNumber >= 2,
                      stagger: 1,
                      asset: 'assets/banana-texture.png',
                      position: const Offset(500, 0),
                    ),

                    // Step 3: Light bulb icon
                    _AnimatedRenderingElement(
                      visible: stepNumber >= 3,
                      stagger: 2,
                      icon: Icons.lightbulb,
                      position: const Offset(-500, 160),
                    ),

                    // Step 4: Camera
                    _AnimatedRenderingElement(
                      visible: stepNumber >= 4,
                      stagger: 3,
                      asset: 'assets/top-left-cam.png',
                      position: const Offset(-500, -320),
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

class _AnimatedRenderingElement extends StatelessWidget {
  const _AnimatedRenderingElement({
    required this.visible,
    required this.stagger,
    this.asset,
    this.icon,
    required this.position,

  });

  final bool visible;
  final int stagger;
  final String? asset;
  final IconData? icon;
  final Offset position;


  @override
  Widget build(BuildContext context) {
    final motion = CupertinoMotion.bouncy(
      duration: const Duration(milliseconds: 600) +
          Duration(milliseconds: 100 * stagger),
    );

    return Center(
      child: MotionBuilder(
        value: visible ? position : position * 3,
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
        child: asset != null
            ? (asset!.contains('cam') 
                ? Image.asset(
                    asset!,
                    scale: 1.6,
                  )
                : Image.asset(
                    asset!,
                    width: 300,
                  ))
            : Icon(
                icon!,
                size: 150,
                color: Colors.amber,
              ),
      ),
    );
  }
}

class _FadeOutElement extends StatelessWidget {
  const _FadeOutElement({
    required this.asset,
    required this.position,
  });

  final String asset;
  final Offset position;

  @override
  Widget build(BuildContext context) {
    final motion = CupertinoMotion.smooth(
      duration: const Duration(milliseconds: 500),
    );

    return Center(
      child: Transform.translate(
        offset: position,
        child: SingleMotionBuilder(
          value: 0.0,
          motion: motion,
          child: asset.contains('cam') 
              ? Image.asset(
                  asset,
                  scale: 1.6,
                )
              : Image.asset(
                  asset,
                  width: 300,
                ),
          builder: (context, value, child) => Opacity(
            opacity: value.clamp(0, 1),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _FadeOutIcon extends StatelessWidget {
  const _FadeOutIcon({
    required this.icon,
    required this.position,
  });

  final IconData icon;
  final Offset position;

  @override
  Widget build(BuildContext context) {
    final motion = CupertinoMotion.smooth(
      duration: const Duration(milliseconds: 500),
    );

    return Center(
      child: Transform.translate(
        offset: position,
        child: SingleMotionBuilder(
          value: 0.0,
          motion: motion,
          child: Icon(
            icon,
            size: 150,
            color: Colors.amber,
          ),
          builder: (context, value, child) => Opacity(
            opacity: value.clamp(0, 1),
            child: child,
          ),
        ),
      ),
    );
  }
}
