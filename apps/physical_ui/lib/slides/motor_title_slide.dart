import 'package:flutter/material.dart';
import 'package:motor_example/title_slide.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart';

class MotorTitleSlide extends FlutterDeckSlideWidget {
  const MotorTitleSlide({super.key});

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => SlideNumber(
        child: TitleSlideExample(),
      ),
    );
  }
}
