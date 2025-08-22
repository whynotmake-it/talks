import 'package:flutter/material.dart';
import 'package:motor/motor.dart';
import 'package:physical_ui/slides/motion/motion_example_app.dart';
import 'package:wnma_talk/content_slide_template.dart';

class MotionSlideNoAnimation extends StatelessWidget {
  const MotionSlideNoAnimation({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentSlideTemplate(
      title: const Text('No Animation'),
      mainContent: MotionExampleApp(
        motion: MaterialSpringMotion.expressiveEffectsFast,
      ),
      description: const Text(
        'This is a simple slide without any motion effects. It serves as a baseline for comparison with other slides that include motion.',
      ),
    );
  }
}
