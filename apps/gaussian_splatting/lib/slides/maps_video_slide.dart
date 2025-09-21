import 'package:flutter/material.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/video.dart';
import 'package:wnma_talk/wnma_talk.dart';

class MapsVideoSlide extends FlutterDeckSlideWidget {
  const MapsVideoSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/maps_video',
          speakerNotes: jesperSlideNotesHeader,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => SlideNumber(
        child: const SizedBox.expand(
          child: Video(
            assetKey: 'assets/maps.mp4',
          ),
        ),
      ),
    );
  }
}
