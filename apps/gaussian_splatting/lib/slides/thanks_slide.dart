import 'package:flutter/material.dart';
import 'package:wnma_talk/big_quote_template.dart';
import 'package:wnma_talk/wnma_talk.dart';

class ThanksSlide extends FlutterDeckSlideWidget {
  const ThanksSlide({super.key});

  @override
  Widget build(BuildContext context) {
    return const BigQuoteTemplate(
      title: Text('Thanks for your attention'),
    );
  }
}
