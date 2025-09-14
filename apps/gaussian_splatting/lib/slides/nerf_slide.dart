import 'package:flutter/material.dart';
import 'package:gaussian_splatting/shared/animated_element.dart';
import 'package:gaussian_splatting/shared/citation_container.dart';
import 'package:wnma_talk/wnma_talk.dart';

class NerfSlide extends FlutterDeckSlideWidget {
  const NerfSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/nerf',
        ),
      );

  @override
  Widget build(BuildContext context) {
    final theme = FlutterDeckTheme.of(context);
    final colorScheme = theme.materialTheme.colorScheme;

    return FlutterDeckSlide.custom(
      builder: (context) => ColoredBox(
        color: colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Title
              AnimatedElement(
                visible: true,
                stagger: 0,
                child: DefaultTextStyle.merge(
                  style: theme.textTheme.header.copyWith(
                    color: colorScheme.onSurface,
                    fontSize: 56,
                  ),
                  child: const Text(
                    'NEURAL RADIANCE FIELDS',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Images in column
              AnimatedElement(
                visible: true,
                stagger: 1,
                child: Column(
                  children: [
                    Image.asset(
                      'assets/nerf1.png',
                      height: 400,
                    ),
    
                    Image.asset(
                      'assets/nerf2.png',
                      height: 300,
                    ),
                  ],
                ),
              ),
                    const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(
                    'Storage: ~2 MB',
                    style: theme.textTheme.bodyLarge.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                       Text(
                    'Implicit Representation',
                    style: theme.textTheme.bodyLarge.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                             Text(
                    'Really slow to render',
                    style: theme.textTheme.bodyLarge.copyWith(
                      color: colorScheme.error,
                    ),
                  )
                ],
              ),

              const SizedBox(height: 60),

              // Citation
              AnimatedElement(
                visible: true,
                stagger: 2,
                child: const CitationContainer(
                  citation: 'Mildenhall, B., Srinivasan, P. P., Tancik, M., Barron, J. T., Ramamoorthi, R., & Ng, R. (2021). Nerf: Representing scenes as neural radiance fields for view synthesis. Communications of the ACM, 65(1), 99-106.',
                  fontSize: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


