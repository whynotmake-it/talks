import 'package:flutter/material.dart';
import 'package:wnma_talk/content_slide_template.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/video.dart';
import 'package:wnma_talk/wnma_talk.dart';

class HowToSlide extends FlutterDeckSlideWidget {
  const HowToSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/how-to',
          steps: 3,
          speakerNotes: timSlideNotesHeader,
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
      mainContent: FlutterDeckSlideStepsBuilder(
        builder: (context, stepNumber) {
          switch (stepNumber) {
            case 1:
              return Center(
                child: Text(
                  '1. Collect Data',
                  style: theme.textTheme.header.copyWith(
                    color: theme.materialTheme.colorScheme.onSurface,
                  ),
                ),
              );
            case 2:
              return const Center(
                child: Video(
                  assetKey: 'assets/colmap.mp4',
                ),
              );
            case 3:
              return const Center(
                child: Video(
                  assetKey: 'assets/brush.mp4',
                ),
              );
            default:
              return const SizedBox.shrink();
          }
        },
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
