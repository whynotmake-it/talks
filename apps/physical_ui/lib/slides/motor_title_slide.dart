import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:motor_example/title_slide.dart';
import 'package:wnma_talk/big_quote_template.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart';

class MotorTitleSlide extends FlutterDeckSlideWidget {
  const MotorTitleSlide({super.key});

  @override
  Widget build(BuildContext context) {
    return BigQuoteTemplate(
      title: const _Logo(),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoTheme(
      data:
          CupertinoTheme.of(
            context,
          ).copyWith(
            textTheme: CupertinoTheme.of(context).textTheme.copyWith(
              textStyle: TextStyle(
                fontFamily: 'Archivo',
                color: Color(0xff2F2E2D),
                fontSize: 64,
                letterSpacing: .9,
                fontVariations: const [
                  FontVariation.weight(500),
                  FontVariation.width(200),
                ],
              ),
            ),
          ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MotorLogo(
              'Motor',
              visible: true,
            ),
          ],
        ),
      ),
    );
  }
}
