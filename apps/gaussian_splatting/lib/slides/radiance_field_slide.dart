import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gaussian_splatting/shared/radiance_field.dart';
import 'package:rivership/rivership.dart';
import 'package:wnma_talk/wnma_talk.dart';

class RadianceFieldSlide extends FlutterDeckSlideWidget {
  const RadianceFieldSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/radiance-field',
          steps: 5,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => FlutterDeckSlideStepsBuilder(
        builder: (context, stepNumber) {
          // Base yaw angle
          const baseYaw = 35 * math.pi / 180.0;
          // Animation range (small animation as requested)
          const animationRange = 180 * math.pi / 180.0;

          // Animate yaw only until step 5 (last step stops animation)
          final animateYaw = stepNumber < 5;

          return SingleMotionBuilder(
            motion: CupertinoMotion(
              duration: const Duration(seconds: 8),
            ),
            value: animateYaw ? baseYaw + animationRange : baseYaw,
            builder: (context, yaw, child) => RadianceFieldScreen(
              showSamplePoints: stepNumber > 2, // OFF steps 0-1, ON step 2+
              showVoxels: stepNumber <= 3, // ON steps 0-3, OFF step 4+
              showSensor: stepNumber > 2, // OFF step 0, ON step 1+
              showRaySamples: stepNumber > 2, // OFF steps 0-3, ON step 4+
              showUI: false,
              yaw: yaw,
              camRadius: 20,
              showAllRays: stepNumber > 1,
              showInstancedVoxels: stepNumber <= 3,
            ),
          );
        },
      ),
    );
  }
}
