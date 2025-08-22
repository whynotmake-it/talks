import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:wnma_talk/title_slide_template.dart';
import 'package:wnma_talk/wnma_talk.dart';

class TitleSlide extends FlutterDeckSlideWidget {
  const TitleSlide({super.key});

  @override
  Widget build(BuildContext context) {
    return TitleSlideTemplate(
      title: Text(
        'Physics-Driven Flutter Apps',
      ),
    );
  }
}
