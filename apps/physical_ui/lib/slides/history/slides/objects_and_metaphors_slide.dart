import 'package:flutter/material.dart';
import 'package:wnma_talk/animated_element.dart';
import 'package:wnma_talk/single_content_slide_template.dart';
import 'package:wnma_talk/wnma_talk.dart';

class ObjectsAndMetaphorsSlide extends FlutterDeckSlideWidget {
  const ObjectsAndMetaphorsSlide({super.key})
      : super(
          configuration: const FlutterDeckSlideConfiguration(
            title: 'Objects and Metaphors',
            route: '/objects-and-metaphors',
            steps: 2,
          ),
        );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlideStepsBuilder(
      builder: (context, stepNumber) {
        return SingleContentSlideTemplate(
          title: const Text('Objects and Metaphors'),
          mainContent: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                AnimatedElement(
                  visible: stepNumber >= 2,
                  stagger: 0,
                  child: Image.asset(
                    'assets/windows1.png',
                    height: 800,
                  ),
                ),
                AnimatedElement(
                  visible: stepNumber >= 3,
                  stagger: 1,
                  child: Image.asset(
                    'assets/apple1.png',
                    height: 700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
