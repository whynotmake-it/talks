import 'package:flutter/material.dart';
import 'package:physical_ui/slides/1_surfaces/surface.dart';
import 'package:wnma_talk/bullet_point.dart';
import 'package:wnma_talk/content_slide_template.dart';
import 'package:wnma_talk/wnma_talk.dart';

class SummarySurfaceSlide extends FlutterDeckSlideWidget {
  const SummarySurfaceSlide({super.key})
      : super(
          configuration: const FlutterDeckSlideConfiguration(
            route: '/surface-summary',
            steps: 4,
          ),
        );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FlutterDeckSlideStepsBuilder(
      builder: (context, stepNumber) => ContentSlideTemplate(
        insetSecondaryContent: true,
        title: const Text('Surface Summary'),
        mainContent: Column(
          spacing: 32,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BulletPoint(
              text: const Text('Create affordances'),
              visible: stepNumber > 0,
            ),
            BulletPoint(
              text: const Text('Establish depth & space'),
              visible: stepNumber > 1,
            ),
            BulletPoint(
              text: const Text('Direct attention & hierarchy'),
              visible: stepNumber > 2,
            ),
            BulletPoint(
              text: const Text('Communicate state & feedback'),
              visible: stepNumber > 3,
            ),
          ],
        ),
        secondaryContent: Surface(
          state: SurfaceState(
            radius: 48,
            noiseOpacity: 1,
            color: theme.colorScheme.secondary,
            elevation: 12,
            gradientOpacity: 1,
            borderOpacity: 1,
            rotateLight: true,
          ),
          phase: 0,
        ),
      ),
    );
  }
}