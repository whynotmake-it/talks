import 'package:flutter/material.dart';
import 'package:gaussian_splatting/shared/animated_element.dart';
import 'package:wnma_talk/single_content_slide_template.dart';
import 'package:wnma_talk/wnma_talk.dart';

class GaussianSplattingOverviewSlide extends FlutterDeckSlideWidget {
  const GaussianSplattingOverviewSlide({super.key})
      : super(
          configuration: const FlutterDeckSlideConfiguration(
            route: '/gaussian-splatting-overview',
          ),
        );

  @override
  Widget build(BuildContext context) {
    final theme = FlutterDeckTheme.of(context);
    final colorScheme = theme.materialTheme.colorScheme;

    return SingleContentSlideTemplate(
      mainContent: FlutterDeckSlideStepsBuilder(
        builder: (context, stepNumber) => ColoredBox(
          color: colorScheme.surface,
          child: Stack(
            children: [
              Center(
                child: AnimatedElement(
                  visible: stepNumber >= 1,
                  stagger: 0,
                  child: Image.asset(
                    'assets/gs-overview.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                bottom: 20,
                left: 20,
                child: AnimatedElement(
                  visible: stepNumber >= 2,
                  stagger: 2,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorScheme.outline, width: 1),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 24,
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward,
                              color: Colors.blue,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Gradient Flow',
                              style: theme.textTheme.bodySmall.copyWith(
                                color: colorScheme.onSurface,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 24,
                              height: 3,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward,
                              color: Colors.black,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Operation Flow',
                              style: theme.textTheme.bodySmall.copyWith(
                                color: colorScheme.onSurface,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ), title: const Text('Gaussian Splatting Overview'),
    );
  }
}

