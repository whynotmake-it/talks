import 'package:flutter/material.dart';
import 'package:wnma_talk/animated_visibility.dart';
import 'package:wnma_talk/big_quote_template.dart';
import 'package:wnma_talk/bullet_point.dart';
import 'package:wnma_talk/content_slide_template.dart';
import 'package:wnma_talk/wnma_talk.dart';

class WhatChangesForYouSlide extends FlutterDeckSlideWidget {
  WhatChangesForYouSlide({super.key})
    : super(
        configuration: FlutterDeckSlideConfiguration(
          route: '/simulation_vs_curve_title',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return BigQuoteTemplate(title: Text('What changes for you?'));
  }
}

class SimulationVsCurveSlide extends FlutterDeckSlideWidget {
  SimulationVsCurveSlide({super.key})
    : super(
        configuration: FlutterDeckSlideConfiguration(
          route: '/simulation_vs_curve',
          steps: 5,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FlutterDeckSlideStepsBuilder(
      builder: (context, step) => ContentSlideTemplate(
        title: AnimatedVisibility(
          animateIn: false,
          visible: step < 5,
          child: Text('Physics simulations – are they just better?'),
        ),
        mainContent: Stack(
          children: [
            Center(
              child: Row(
                spacing: 64,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AnimatedVisibility(
                      visible: step > 1 && step < 5,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'The good',
                            style: FlutterDeckTheme.of(
                              context,
                            ).textTheme.subtitle,
                          ),
                          const SizedBox(height: 48),
                          IconTheme.merge(
                            data: IconThemeData(
                              color: colorScheme.primaryFixedDim,
                            ),
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
                                  text: Text(
                                    "Can't really be used incorrectly",
                                  ),
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
                      animateIn: false,
                      visible: step < 5,
                      opacityFrom: .5,
                      scaleFrom: 0.8,
                      from: Offset.zero,
                      child: AnimatedVisibility(
                        visible: step > 2,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'The bad*',
                              style: FlutterDeckTheme.of(
                                context,
                              ).textTheme.subtitle,
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
                                    text: Text('Cumbersome in Flutter'),
                                  ),
                                  BulletPoint(
                                    icon: Icon(Icons.remove_rounded),
                                    text: Text('No guaranteed duration'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: AnimatedVisibility(
                      visible: step > 3 && step < 5,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'The ugly',
                            style: FlutterDeckTheme.of(
                              context,
                            ).textTheme.subtitle,
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
            Center(
              child: AnimatedVisibility(
                opacityFrom: 1,
                from: Offset(0, 500),
                scaleFrom: 0.5,
                visible: step == 5,
                child: Transform.rotate(
                  angle: .23,
                  child: Material(
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 10,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        "Fixable",
                        style:
                            FlutterDeckTheme.of(
                              context,
                            ).textTheme.display.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
