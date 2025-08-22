import 'package:flutter/material.dart';
import 'package:wnma_talk/big_quote_template.dart';
import 'package:wnma_talk/wnma_talk.dart';

class HowDidWeGetHereSlide extends FlutterDeckSlideWidget {
  const HowDidWeGetHereSlide({super.key});

  @override
  Widget build(BuildContext context) {
    return BigQuoteTemplate(
      title: Text(
        'How did we get here?',
      ),
    );
  }
}
