import 'package:flutter/material.dart';
import 'package:wnma_talk/big_quote_template.dart';
import 'package:wnma_talk/wnma_talk.dart';

class ThanksSlide extends FlutterDeckSlideWidget {
  const ThanksSlide({super.key});

  @override
  Widget build(BuildContext context) {
    return  BigQuoteTemplate(
      title: Text('Thanks! Scan QR for resources.'),
      footer: Padding(
        padding: EdgeInsetsGeometry.all(72),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
         
            Material(
              elevation: 8,
              borderRadius: BorderRadius.all(Radius.circular(32)),
              clipBehavior: Clip.antiAlias,
              
              child: Image.asset('assets/linkqrcode.png'))
          ],
        ),
      ),
    );
  }
}
