import 'package:flutter/material.dart';
import 'package:wnma_talk/animated_element.dart';
import 'package:wnma_talk/single_content_slide_template.dart';
import 'package:wnma_talk/video.dart';
import 'package:wnma_talk/wnma_talk.dart';

class ShadingAnimationSlide extends FlutterDeckSlideWidget {
  const ShadingAnimationSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          title: 'Shading and Animation',
          route: '/shading-animation',
          steps: 4,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlideStepsBuilder(
      builder: (context, stepNumber) {
        return SingleContentSlideTemplate(
          title: const Text('Shading and Animation'),
          mainContent: Stack(
            clipBehavior: Clip.none,

            children: [
              // Background layer: Mac OS X Leopard desktop
              Positioned(
                left: 0,
                top: 0,
                child: AnimatedElement(
                  visible: stepNumber >= 2,
                  stagger: 0,
                  child: Transform.rotate(
                    angle: -0.05,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.asset(
                        'assets/history/10-5-Leopard-Desktop.png',
                        height: 500,
                      ),
                    ),
                  ),
                ),
              ),

              // Middle layer: Windows 7 Aero
              Positioned(
                right: 0,
                top: 0,
                child: AnimatedElement(
                  visible: stepNumber >= 3,
                  stagger: 1,
                  child: Transform.rotate(
                    angle: 0.08, // Opposite rotation
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.asset(
                        'assets/history/windows7.webp',
                        height: 500,
                      ),
                    ),
                  ),
                ),
              ),

              // iPhone layer: Mobile revolution
              Positioned(
                bottom: 0,
                left: 0,
                child: AnimatedElement(
                  visible: stepNumber >= 4,
                  stagger: 3,
                  child: Transform.rotate(
                    angle: -0.1, // Slight rotation
                    child: Image.asset(
                      'assets/iphone.png',
                      height: 400,
                    ),
                  ),
                ),
              ),

              // Foreground layer: Cover Flow video
              Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedElement(
                  visible: stepNumber >= 4,
                  stagger: 3,
                  child: SizedBox(
                    width: 500,
                    child: AspectRatio(
                      aspectRatio: 1006 / 1044,

                      child: const Video(
                        assetKey: 'assets/coverflow.mov',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
