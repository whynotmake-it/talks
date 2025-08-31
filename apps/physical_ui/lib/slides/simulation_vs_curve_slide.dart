import 'package:flutter/material.dart';
import 'package:wnma_talk/animated_visibility.dart';
import 'package:wnma_talk/bullet_point.dart';
import 'package:wnma_talk/content_slide_template.dart';
import 'package:wnma_talk/wnma_talk.dart';

class SimulationVsCurveSlide extends FlutterDeckSlideWidget {
  SimulationVsCurveSlide({super.key})
    : super(
        configuration: FlutterDeckSlideConfiguration(
          route: '/simulation_vs_curve',
          steps: 4,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FlutterDeckSlideStepsBuilder(
      builder: (context, step) => ContentSlideTemplate(
        title: Text('Springs all the way?'),
        mainContent: Center(
          child: Row(
            spacing: 64,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AnimatedVisibility(
                  visible: step > 1,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'The good',
                        style: FlutterDeckTheme.of(context).textTheme.subtitle,
                      ),
                      const SizedBox(height: 48),
                      IconTheme.merge(
                        data: IconThemeData(color: colorScheme.primaryFixedDim),
                        child: BulletList(
                          children: const [
                            BulletPoint(
                              icon: Icon(Icons.check_rounded),
                              text: Text('Highly dynamic'),
                            ),
                            BulletPoint(
                              icon: Icon(Icons.check_rounded),
                              text: Text(
                                'Perfect for animations driven by user input',
                              ),
                            ),
                            BulletPoint(
                              icon: Icon(Icons.check_rounded),
                              text: Text("Can't really be used incorrectly"),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: AnimatedVisibility(
                  visible: step > 2,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'The bad*',
                        style: FlutterDeckTheme.of(context).textTheme.subtitle,
                      ),
                      const SizedBox(height: 48),
                      IconTheme(
                        data: IconThemeData(color: colorScheme.tertiary),
                        child: BulletList(
                          children: const [
                            BulletPoint(
                              icon: Icon(Icons.remove_rounded),
                              text: Text(
                                'Requires multi-dimensional simulation',
                              ),
                            ),
                            BulletPoint(
                              icon: Icon(Icons.remove_rounded),
                              text: Text('No guaranteed duration'),
                            ),
                            BulletPoint(
                              icon: Icon(Icons.remove_rounded),
                              text: Text('Cumbersome in Flutter'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: AnimatedVisibility(
                  visible: step > 3,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'The ugly',
                        style: FlutterDeckTheme.of(context).textTheme.subtitle,
                      ),
                      const SizedBox(height: 48),
                      IconTheme(
                        data: IconThemeData(color: colorScheme.error),
                        child: BulletList(
                          children: const [
                            BulletPoint(
                              icon: Icon(Icons.close_rounded),
                              text: Text(
                                'Configuring can be unpredictable',
                              ),
                            ),
                            BulletPoint(
                              icon: Icon(Icons.close_rounded),
                              text: Text("Design handoff trickier"),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
