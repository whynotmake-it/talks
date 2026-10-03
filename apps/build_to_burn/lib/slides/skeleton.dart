import 'package:build_to_burn/shared/slide_frame.dart';
import 'package:build_to_burn/shared/style.dart';
import 'package:flutter/material.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart';

/// A throwaway placeholder that holds an agenda section's place in the
/// deck: a plain title, and the facts in the speaker notes.
///
/// Replace these with real slides. Nothing here is a layout to build on.
class SkeletonSlide extends FlutterDeckSlideWidget {
  const SkeletonSlide({
    required this.title,
    required super.configuration,
    super.key,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) {
        final p = Palette.of(context);
        return SlideFrame(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: p.display),
              const SizedBox(height: 32),
              Text(
                'Skeleton. Content and layout come later; the facts are in '
                'the speaker notes.',
                style: p.caption,
              ),
            ],
          ),
        );
      },
    );
  }
}

const fixesSlide = SkeletonSlide(
  title: 'Fixes: idle screens and animating screens',
  configuration: FlutterDeckSlideConfiguration(
    route: '/fixes',
    title: 'Fixes',
    speakerNotes: jesperSlideNotesHeader,
  ),
);

const productionSlide = SkeletonSlide(
  title: 'Production, and a skill that reads the trace',
  configuration: FlutterDeckSlideConfiguration(
    route: '/production',
    title: 'Production + AI skill',
    speakerNotes: timSlideNotesHeader,
  ),
);

const closeSlide = SkeletonSlide(
  title: 'The Monday checklist',
  configuration: FlutterDeckSlideConfiguration(
    route: '/close',
    title: 'Close',
    speakerNotes: jesperSlideNotesHeader,
  ),
);
