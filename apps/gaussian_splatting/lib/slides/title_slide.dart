import 'package:flutter/material.dart';
import 'package:wnma_talk/title_slide_template.dart';
import 'package:wnma_talk/wnma_talk.dart';

class TitleSlide extends FlutterDeckSlideWidget {
  const TitleSlide({super.key});

  @override
  Widget build(BuildContext context) {
    return TitleSlideTemplate(
      title: Text(
        'Gaussian Splatting – An Early Field Report',
      ),
    );
  }
}
