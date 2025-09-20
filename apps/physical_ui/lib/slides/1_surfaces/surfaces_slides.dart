import 'package:flutter/material.dart';
import 'package:physical_ui/slides/1_surfaces/surface.dart';
import 'package:rivership/rivership.dart';
import 'package:wnma_talk/bullet_point.dart';
import 'package:wnma_talk/content_slide_template.dart';
import 'package:wnma_talk/wnma_talk.dart';

final surfacesSlides = [WhatAreSurfaces(), Light(), SpecialEffectsSlide()];

class WhatAreSurfaces extends FlutterDeckSlideWidget {
  WhatAreSurfaces({super.key})
    : super(
        configuration: FlutterDeckSlideConfiguration(
          route: '/surfaces/what_are_surfaces',
          steps: 5,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FlutterDeckSlideStepsBuilder(
      builder: (context, stepNumber) => ContentSlideTemplate(
        insetSecondaryContent: true,
        title: Text('What are Surfaces?'),
        mainContent: AnimatedSizeSwitcher(
          child: stepNumber == 5
              ? Surface(state: SurfaceState(), phase: 0)
              : Column(
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
              5: SurfaceState(
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
              phase: phase.clamp(0, 4),
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
        insetSecondaryContent: true,
        title: Text('Light'),
        mainContent: AnimatedSizeSwitcher(
          child: stepNumber == 5
              ? Surface(
                  state: SurfaceState(
                    radius: 48,
                    noiseOpacity: 1,
                    color: theme.colorScheme.secondary,
                  ),
                  phase: 0,
                )
              : Column(
                  spacing: 32,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Think about how light interacts with your surface..'),
                    const SizedBox(height: 64),
                    BulletPoint(text: Text('Shadows'), visible: stepNumber > 1),
                    BulletPoint(
                      text: Text('Gradients'),
                      visible: stepNumber > 2,
                    ),
                    BulletPoint(text: Text('Borders'), visible: stepNumber > 3),
                  ],
                ),
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
              // Don't tell about last phase change so it doesn't bounce
              phase: phase.clamp(0, 4),
            );
          },
        ),
      ),
    );
  }
}

class SpecialEffectsSlide extends FlutterDeckSlideWidget {
  SpecialEffectsSlide({super.key})
    : super(
        configuration: FlutterDeckSlideConfiguration(
          route: '/surfaces/special_effects',
          steps: 4,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FlutterDeckSlideStepsBuilder(
      builder: (context, stepNumber) => ContentSlideTemplate(
        insetSecondaryContent: true,
        title: Text('Materials'),
        mainContent: Column(
          spacing: 32,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Materials are defined by their surface properties and how light '
              'interacts with them.',
            ),
          ],
        ),
        secondaryContent: SequenceMotionBuilder(
          sequence: StateSequence(
            <int, SurfaceState>{
              1: SurfaceState(
                radius: 48,
                noiseOpacity: 1,
                color: theme.colorScheme.secondary,
                elevation: 12,
                gradientOpacity: 1,
                borderOpacity: 1,
                rotateLight: true,
              ),
              2: SurfaceState(
                radius: 48,
                noiseOpacity: 1,
                rotateLight: true,
                elevation: 12,
                effect: SpecialEffects.halofoil,
              ),
              3: SurfaceState(
                radius: 48,
                rotateLight: true,
                effect: SpecialEffects.liquidMetal,
              ),
              4: SurfaceState(
                radius: 48,
                rotateLight: true,
                effect: SpecialEffects.liquidGlass,
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
