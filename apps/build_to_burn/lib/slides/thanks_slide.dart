import 'package:build_to_burn/shared/entrance.dart';
import 'package:build_to_burn/shared/slide_frame.dart';
import 'package:build_to_burn/shared/style.dart';
import 'package:flutter/material.dart';
import 'package:wnma_talk/wnma_talk.dart';

class ThanksSlide extends FlutterDeckSlideWidget {
  const ThanksSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/thanks',
          title: 'Thank you',
          speakerNotes: 'Placeholder. Add the link and QR code to the skill.',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) {
        final p = Palette.of(context);
        return SlideFrame(
          child: Entrance(
            count: 2,
            builder: (context, reveal) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                reveal(0, Text('Thank you!', style: p.hero)),
                const SizedBox(height: 40),
                reveal(
                  1,
                  Text('whynotmake.it', style: mono(40, color: p.accent)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
