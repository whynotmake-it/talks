import 'package:build_to_burn/shared/entrance.dart';
import 'package:build_to_burn/shared/slide_frame.dart';
import 'package:build_to_burn/shared/style.dart';
import 'package:flutter/material.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart';

class TitleSlide extends FlutterDeckSlideWidget {
  const TitleSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/title',
          title: 'Title',
          speakerNotes: timSlideNotesHeader,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) {
        final p = Palette.of(context);
        return SlideFrame(
          child: Entrance(
            count: 3,
            builder: (context, reveal) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                reveal(
                  0,
                  Text('FLUTTERCON 2026 · LIGHTNING TALK', style: p.eyebrow),
                ),
                const SizedBox(height: 40),
                reveal(1, Text('From build\nto burn', style: p.hero)),
                const Spacer(),
                reveal(
                  2,
                  Text(
                    'whynotmake.it',
                    style: p.title.copyWith(color: p.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
