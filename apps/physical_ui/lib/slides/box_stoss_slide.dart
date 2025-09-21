import 'package:flutter/material.dart';
import 'package:rivership/rivership.dart';
import 'package:wnma_talk/content_slide_template.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart';

class BoxStossSlide extends FlutterDeckSlideWidget {
  const BoxStossSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          title: "What's missing here?",
          route: '/box-stoss',
          speakerNotes: jesperSlideNotesHeader,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ContentSlideTemplate(
      insetSecondaryContent: true,
      title: const Text("What's missing here?"),
      mainContent: Row(
        children: [
          Expanded(
            child: SequenceMotionBuilder(
              sequence: StepSequence.withMotions(const [
                (0.0, NoMotion(Duration(seconds: 1))),
                (
                  1.0,
                  CurvedMotion(
                    Duration(seconds: 1),
                    Curves.bounceOut,
                  ),
                ),
              ]),
              converter: SingleMotionConverter(),
              builder: (context, value, _, child) => Align(
                alignment: Alignment(0, value * 2 - 1),
                child: child,
              ),
              child: ColoredBox(
                color: Theme.of(context).colorScheme.primary,
                child: const SizedBox.square(
                  dimension: 200,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
