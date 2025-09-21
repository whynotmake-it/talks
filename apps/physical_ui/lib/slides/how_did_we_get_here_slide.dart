import 'package:flutter/material.dart';
import 'package:wnma_talk/big_quote_template.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart';

class HowDidWeGetHereSlide extends FlutterDeckSlideWidget {
  const HowDidWeGetHereSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/how-did-we-get-here',
          speakerNotes: timSlideNotesHeader,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return BigQuoteTemplate(
      title: Text(
        'How did we get here?',
      ),
    );
  }
}
