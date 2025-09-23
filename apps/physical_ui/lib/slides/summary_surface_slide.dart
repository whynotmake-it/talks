import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:motor/motor.dart';
import 'package:physical_ui/slides/1_surfaces/surface.dart';
import 'package:wnma_talk/bullet_point.dart';
import 'package:wnma_talk/content_slide_template.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart';

class SummarySurfaceSlide extends FlutterDeckSlideWidget {
  const SummarySurfaceSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/surface-summary',
          steps: 4,
          speakerNotes: jesperSlideNotesHeader,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HookBuilder(
      builder: (context) {
        final pressed = useState(false);
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
            secondaryContent: InkWell(
              onTapDown: (details) => pressed.value = true,
              onTapCancel: () => pressed.value = false,
              onTapUp: (details) => pressed.value = false,
              child: MotionBuilder<SurfaceState>(
                motion: pressed.value
                    ? CupertinoMotion.interactive()
                    : CupertinoMotion.snappy(),
                converter: surfaceStateConverter,
                builder: (context, value, child) => Transform.scale(
                  transformHitTests: false,
                  scale: lerpDouble(.95, 1, value.gradientOpacity),
                  child: Surface(
                    state: value,
                    phase: 0,
                  ),
                ),
                value: pressed.value
                    ? SurfaceState(
                        radius: 48,
                        noiseOpacity: 1,
                        color: theme.colorScheme.secondary,
                        rotateLight: true,
                      )
                    : SurfaceState(
                        radius: 48,
                        noiseOpacity: 1,
                        color: theme.colorScheme.secondary,
                        elevation: 12,
                        gradientOpacity: 1,
                        borderOpacity: 1,
                        rotateLight: true,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}
