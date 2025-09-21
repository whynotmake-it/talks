import 'package:flutter/material.dart';
import 'package:wnma_talk/single_content_slide_template.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart';

class DesignSystemSlide extends FlutterDeckSlideWidget {
  const DesignSystemSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          title: 'Design is...',
          route: '/design-is',
          speakerNotes: jesperSlideNotesHeader,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SingleContentSlideTemplate(
      title: const Text('Design is...'),
      mainContent: Center(
        child: Image.asset(
          'assets/design.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
