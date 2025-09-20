import 'package:flutter/material.dart';
import 'package:wnma_talk/video.dart';
import 'package:wnma_talk/wnma_talk.dart';

class FoodVideoSlide extends FlutterDeckSlideWidget {
  const FoodVideoSlide({super.key});

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => const SizedBox.expand(
        child: Video(
          assetKey: 'assets/food.mp4',

        ),
      ),
    );
  }
}
