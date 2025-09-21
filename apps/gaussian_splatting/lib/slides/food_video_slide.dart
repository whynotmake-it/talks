import 'package:flutter/material.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/video.dart';
import 'package:wnma_talk/wnma_talk.dart';

class FoodVideoSlide extends FlutterDeckSlideWidget {
  const FoodVideoSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/food_video',
          speakerNotes: jesperSlideNotesHeader,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => SlideNumber(
        child: const SizedBox.expand(
          child: Video(
            assetKey: 'assets/food.mp4',
          ),
        ),
      ),
    );
  }
}
