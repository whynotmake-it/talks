import 'dart:math';

import 'package:flutter/material.dart';
import 'package:rivership/rivership.dart';
import 'package:wnma_talk/bullet_point.dart';
import 'package:wnma_talk/content_slide_template.dart';
import 'package:wnma_talk/wnma_talk.dart';

final surfacesSlides = [WhatAreSurfaces(), Light()];

class WhatAreSurfaces extends FlutterDeckSlideWidget {
  WhatAreSurfaces({super.key})
    : super(
        configuration: FlutterDeckSlideConfiguration(
          route: '/surfaces/what_are_surfaces',
          steps: 4,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FlutterDeckSlideStepsBuilder(
      builder: (context, stepNumber) => ContentSlideTemplate(
        title: Text('What are Surfaces?'),
        mainContent: Column(
          spacing: 32,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Every UI element starts with a surface.'),
            const SizedBox(height: 64),
            BulletPoint(text: Text('Color'), visible: stepNumber > 1),
            BulletPoint(text: Text('Shape'), visible: stepNumber > 2),
            BulletPoint(text: Text('Texture'), visible: stepNumber > 3),
          ],
        ),
        secondaryContent: SequenceMotionBuilder(
          sequence: StateSequence(
            <int, SurfaceState>{
              1: (
                radius: 0,
                noiseOpacity: 0,
                color: theme.colorScheme.surface,
                elevation: 0,
                gradientOpacity: 0,
                lightDirection: 0,
              ),
              2: (
                radius: 0,
                noiseOpacity: 0,
                color: theme.colorScheme.secondary,
                elevation: 0,
                gradientOpacity: 0,
                lightDirection: 0,
              ),
              3: (
                radius: 48,
                noiseOpacity: 0,
                color: theme.colorScheme.secondary,
                elevation: 0,
                gradientOpacity: 0,
                lightDirection: 0,
              ),
              4: (
                radius: 48,
                noiseOpacity: 1,
                color: theme.colorScheme.secondary,
                elevation: 0,
                gradientOpacity: 0,
                lightDirection: 0,
              ),
            },
            motion: CupertinoMotion.smooth(),
          ),
          currentPhase: stepNumber,
          playing: false,
          converter: surfaceStateConverter,
          builder: (context, value, phase, child) {
            return _Surface(
              state: value,
              phase: phase,
            );
          },
        ),
      ),
    );
  }
}

class Light extends FlutterDeckSlideWidget {
  Light({super.key})
    : super(
        configuration: FlutterDeckSlideConfiguration(
          route: '/surfaces/light',
          steps: 4,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FlutterDeckSlideStepsBuilder(
      builder: (context, stepNumber) => ContentSlideTemplate(
        title: Text('Light'),
        mainContent: Column(
          spacing: 32,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Think about how light interacts with your surface..'),
            const SizedBox(height: 64),
            BulletPoint(text: Text('Shadows'), visible: stepNumber > 1),
            BulletPoint(text: Text('Gradients'), visible: stepNumber > 2),
            BulletPoint(text: Text('Borders'), visible: stepNumber > 3),
          ],
        ),
        secondaryContent: SequenceMotionBuilder(
          sequence: StateSequence(
            <int, SurfaceState>{
              1: (
                radius: 48,
                noiseOpacity: 1,
                color: theme.colorScheme.secondary,
                elevation: 0,
                gradientOpacity: 0,
                lightDirection: 0,
              ),
              2: (
                radius: 48,
                noiseOpacity: 1,
                color: theme.colorScheme.secondary,
                elevation: 12,
                gradientOpacity: 0,
                lightDirection: 0,
              ),
              3: (
                radius: 48,
                noiseOpacity: 1,
                color: theme.colorScheme.secondary,
                elevation: 12,
                gradientOpacity: 1,
                lightDirection: 0,
              ),
              4: (
                radius: 48,
                noiseOpacity: 1,
                color: theme.colorScheme.secondary,
                elevation: 12,
                gradientOpacity: 1,
                lightDirection: pi / 4 * 3,
              ),
            },
            motion: CupertinoMotion.smooth(),
          ),
          currentPhase: stepNumber,
          playing: false,
          converter: surfaceStateConverter,
          builder: (context, value, phase, child) {
            return _Surface(
              state: value,
              phase: phase,
            );
          },
        ),
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.state,
    required this.phase,
  });

  final SurfaceState state;
  final int phase;

  @override
  Widget build(BuildContext context) {
    return SequenceMotionBuilder(
      sequence: StepSequence.withMotions(
        [
          (1.0, Motion.interactiveSpring()),
          (0.95, Motion.interactiveSpring().trimmed(endTrim: .8)),
          (1.0, Motion.smoothSpring()),
        ],
      ),

      restartTrigger: phase,
      converter: SingleMotionConverter(),
      builder: (context, scale, _, child) {
        // Calculate shadow offsets based on light direction and elevation
        final closeDistance = state.elevation * 1;
        final farDistance = state.elevation * 2;

        final closeShadowOffset = Offset(
          sin(state.lightDirection + pi) * closeDistance,
          -cos(state.lightDirection + pi) * closeDistance,
        );

        final farShadowOffset = Offset(
          sin(state.lightDirection + pi) * farDistance,
          -cos(state.lightDirection + pi) * farDistance,
        );

        return Center(
          child: Transform.scale(
            scale: scale,
            child: Container(
              decoration: ShapeDecoration(
                color: state.color,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(state.radius),
                ),
                shadows: state.elevation > 0
                    ? [
                        // Far, soft shadow for ambient depth
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          offset: farShadowOffset,
                          blurRadius: state.elevation * 1.5,
                          spreadRadius: state.elevation * 0.2,
                        ),
                        // Close, sharp shadow for definition
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          offset: closeShadowOffset,
                          blurRadius: state.elevation,
                        ),
                      ]
                    : null,
              ),
              foregroundDecoration: ShapeDecoration(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(state.radius),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: state.gradientOpacity),
                    Colors.black.withValues(alpha: state.gradientOpacity),
                  ],
                  stops: const [0, 1],
                  transform: GradientRotation(state.lightDirection),
                ),
                image: DecorationImage(
                  image: AssetImage('assets/noise.png'),
                  fit: BoxFit.scaleDown,
                  colorFilter: ColorFilter.mode(
                    state.color.withValues(alpha: .5),
                    BlendMode.colorDodge,
                  ),
                  repeat: ImageRepeat.repeat,
                  scale: 1 - .5 * (state.noiseOpacity),
                  opacity: state.noiseOpacity.clamp(0, 1),
                ),
              ),
              child: const SizedBox.square(
                dimension: 400,
              ),
            ),
          ),
        );
      },
    );
  }
}

typedef SurfaceState = ({
  double radius,
  double noiseOpacity,
  Color color,
  double elevation,
  double gradientOpacity,
  double lightDirection,
});

final surfaceStateConverter = MotionConverter<SurfaceState>.custom(
  normalize: (value) => [
    value.radius,
    value.noiseOpacity,
    value.color.r,
    value.color.g,
    value.color.b,
    value.color.a,
    value.elevation,
    value.gradientOpacity,
    value.lightDirection,
  ],
  denormalize: (value) => (
    radius: value[0],
    noiseOpacity: value[1],
    color: Color.from(
      red: value[2],
      green: value[3],
      blue: value[4],
      alpha: value[5],
    ),
    elevation: value[6],
    gradientOpacity: value[7],
    lightDirection: value[8],
  ),
);
