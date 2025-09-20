import 'package:flutter/cupertino.dart';
import 'package:rivership/rivership.dart';
import 'package:wnma_talk/content_slide_template.dart';
import 'package:wnma_talk/wnma_talk.dart';

final surfacesSlides = [WhatAreSurfaces()];

class WhatAreSurfaces extends FlutterDeckSlideWidget {
  WhatAreSurfaces({super.key})
    : super(
        configuration: FlutterDeckSlideConfiguration(
          route: '/surfaces/what_are_surfaces',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ContentSlideTemplate(
      title: Text('What are Surfaces?'),
      mainContent: Text(
        'Surfaces are the visual layers that separate different parts of an interface. They provide structure, hierarchy, and context to the user interface, making it easier for users to navigate and interact with the application.',
      ),
      secondaryContent: SequenceMotionBuilder(
        sequence: StepSequence(
          const <SurfaceState>[
            (radius: 0, noiseOpacity: 0, color: CupertinoColors.black),
            (radius: 0, noiseOpacity: 0, color: CupertinoColors.systemBlue),
            (radius: 48, noiseOpacity: 0, color: CupertinoColors.systemBlue),
            (radius: 48, noiseOpacity: 0, color: CupertinoColors.systemBlue),
          ],
          loop: LoopMode.loop,
          motion: CupertinoMotion.bouncy(),
        ),
        converter: surfaceStateConverter,
        builder: (context, value, _, child) => Center(
          child: Container(
            width: 300,
            height: 300,
            decoration: ShapeDecoration(
              color: value.color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(value.radius),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

typedef SurfaceState = ({double radius, double noiseOpacity, Color color});
final surfaceStateConverter = MotionConverter<SurfaceState>.custom(
  normalize: (value) => [
    value.radius,
    value.noiseOpacity,
    value.color.r,
    value.color.g,
    value.color.b,
    value.color.a,
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
  ),
);
