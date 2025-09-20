import 'dart:math';

import 'package:flutter/material.dart';
import 'package:physical_ui/slides/1_surfaces/surface.dart';
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
              1: SurfaceState(),
              2: SurfaceState(
                color: theme.colorScheme.secondary,
              ),
              3: SurfaceState(
                radius: 48,
                color: theme.colorScheme.secondary,
              ),
              4: SurfaceState(
                radius: 48,
                color: theme.colorScheme.secondary,
                noiseOpacity: 1,
              ),
            },
            motion: CupertinoMotion.smooth(),
          ),
          currentPhase: stepNumber,
          playing: false,
          converter: surfaceStateConverter,
          builder: (context, value, phase, child) {
            return Surface(
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
          steps: 5,
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
              1: SurfaceState(
                radius: 48,
                noiseOpacity: 1,
                color: theme.colorScheme.secondary,
              ),
              2: SurfaceState(
                radius: 48,
                noiseOpacity: 1,
                color: theme.colorScheme.secondary,
                elevation: 12,
              ),
              3: SurfaceState(
                radius: 48,
                noiseOpacity: 1,
                color: theme.colorScheme.secondary,
                elevation: 12,
                gradientOpacity: 1,
              ),
              4: SurfaceState(
                radius: 48,
                noiseOpacity: 1,
                color: theme.colorScheme.secondary,
                elevation: 12,
                gradientOpacity: 1,
                borderOpacity: 1,
              ),
              5: SurfaceState(
                radius: 48,
                noiseOpacity: 1,
                color: theme.colorScheme.secondary,
                elevation: 12,
                gradientOpacity: 1,
                borderOpacity: 1,
                rotateLight: true,
              ),
            },
            motion: CupertinoMotion.smooth(),
          ),
          currentPhase: stepNumber,
          playing: false,
          converter: surfaceStateConverter,
          builder: (context, value, phase, child) {
            return Surface(
              state: value,
              phase: phase,
            );
          },
        ),
      ),
    );
  }
}
