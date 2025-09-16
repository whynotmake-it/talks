import 'package:flutter/material.dart';
import 'package:gaussian_splatting/shared/scrollable_code_highlight.dart';
import 'package:wnma_talk/content_slide_template.dart';
import 'package:wnma_talk/wnma_talk.dart';

class HowToSlide extends FlutterDeckSlideWidget {
  const HowToSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/how-to',
          // steps: 1,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = FlutterDeckTheme.of(context);

    return ContentSlideTemplate(
      title: const Text(
        'I want to try this! How?',
        textAlign: TextAlign.left,
      ),
      mainContent: FlutterDeckBulletList(
        items: const [
          '1. Collect data.',
          '2. Estimate poses',
          '3. Optimize',
        ],

      ),

      secondaryContent: Center(
        child: Image.asset(
          'assets/how_to.png',
          fit: BoxFit.fitWidth,
        ),
      ),
    );
  }
}
