import 'package:flutter/material.dart';
import 'package:wnma_talk/wnma_talk.dart';
import 'package:wnma_talk/content_slide_template.dart';

class RadianceFieldSlide extends FlutterDeckSlideWidget {
  const RadianceFieldSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/radiance-field',
          steps: 1,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ContentSlideTemplate(
      title: Text('Radiance Fields'),
      mainContent: Placeholder(),
    );
  }
}