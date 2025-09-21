import 'package:flutter/material.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/video.dart';
import 'package:wnma_talk/wnma_talk.dart';

class ArVideoSlide extends FlutterDeckSlideWidget {
  const ArVideoSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/ar_video',
          speakerNotes: timSlideNotesHeader,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => const SizedBox.expand(
        child: SlideNumber(
          child: Video(
            assetKey: 'assets/ar.mp4',
          ),
        ),
      ),
    );
  }
}
