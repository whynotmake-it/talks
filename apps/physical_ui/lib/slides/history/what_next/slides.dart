import 'package:flutter/cupertino.dart';
import 'package:wnma_talk/animated_visibility.dart';
import 'package:wnma_talk/content_slide_template.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/video.dart';
import 'package:wnma_talk/wnma_talk.dart';

final whatNextSlides = [
  VisionProUiSlide(),
  ReturnToSkeumorphismSlide(),
  UiAsFunctionSlide(),
  ComputingPowerSlide(),
  NotSoFastSlide(),
  NotSoFastSlide2(),
];

class VisionProUiSlide extends FlutterDeckSlideWidget {
  VisionProUiSlide({super.key})
    : super(
        configuration: FlutterDeckSlideConfiguration(
          route: '/history/what_next/vision_pro_ui',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ContentSlideTemplate(
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 32,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 32,
              children: const [
                Expanded(
                  child: AnimatedVisibility(
                    from: Offset(-500, -500),
                    child: FittedBox(
                      clipBehavior: Clip.hardEdge,
                      fit: BoxFit.cover,
                      child: Video(assetKey: 'assets/vision_pro_windows.mp4'),
                    ),
                  ),
                ),
                Expanded(
                  child: AnimatedVisibility(
                    stagger: 3,
                    from: Offset(100, -500),
                    child: FittedBox(
                      clipBehavior: Clip.hardEdge,
                      fit: BoxFit.cover,
                      child: Video(assetKey: 'assets/vision_pro_widget.mp4'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedVisibility(
              stagger: 1,
              from: const Offset(10, 500),
              child: SizedBox(
                child: Image.asset(
                  'assets/vision_icons.png',
                  height: 400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ReturnToSkeumorphismSlide extends FlutterDeckSlideWidget {
  ReturnToSkeumorphismSlide({super.key})
    : super(
        configuration: FlutterDeckSlideConfiguration(
          route: '/history/what_next/return_to_skeumorphism',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ContentSlideTemplate(
      title: Text('Imitating Physical Objects is Back'),
      fitSecondaryContent: true,
      secondaryContent: AnimatedVisibility(
        stagger: 3,
        from: const Offset(500, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(64),
          child: FittedBox(
            child: Video(assetKey: 'assets/arc_summarize.mp4'),
          ),
        ),
      ),
      mainContent: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 32,
        children: const [
          Expanded(
            child: AnimatedVisibility(
              from: Offset(-500, -00),
              child: FittedBox(
                clipBehavior: Clip.hardEdge,
                fit: BoxFit.cover,
                child: Video(assetKey: 'assets/dynamic_island.mp4'),
              ),
            ),
          ),
          Expanded(
            child: AnimatedVisibility(
              stagger: 1,
              from: Offset(-500, 0),
              child: FittedBox(
                clipBehavior: Clip.hardEdge,
                fit: BoxFit.cover,
                child: Video(
                  assetKey: 'assets/fluent_design.mp4',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UiAsFunctionSlide extends FlutterDeckSlideWidget {
  UiAsFunctionSlide({super.key})
    : super(
        configuration: FlutterDeckSlideConfiguration(
          route: '/history/what_next/ui_as_function',
          speakerNotes: jesperSlideNotesHeader,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ContentSlideTemplate(
      title: Text('Dynamically Adapting UIs'),
      insetSecondaryContent: true,
      mainContent: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 32,
        children: const [
          Expanded(
            flex: 2,
            child: FittedBox(
              clipBehavior: Clip.hardEdge,
              fit: BoxFit.cover,
              child: Video(
                assetKey: 'assets/material_you_colors.mp4',
              ),
            ),
          ),
          Flexible(
            child: FittedBox(
              clipBehavior: Clip.hardEdge,
              fit: BoxFit.cover,
              child: Video(
                assetKey: 'assets/glass_adapt.mp4',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ComputingPowerSlide extends FlutterDeckSlideWidget {
  ComputingPowerSlide({super.key})
    : super(
        configuration: FlutterDeckSlideConfiguration(
          route: '/history/what_next/computing_power',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ContentSlideTemplate(
      title: Text('More Computing Power finally enables Realism?'),
      insetSecondaryContent: true,
      mainContent: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 32,
        children: [
          Flexible(
            child: FittedBox(
              clipBehavior: Clip.hardEdge,
              child: Image.asset('assets/computing_power.png'),
            ),
          ),
        ],
      ),
    );
  }
}

class NotSoFastSlide extends FlutterDeckSlideWidget {
  NotSoFastSlide({super.key})
    : super(
        configuration: FlutterDeckSlideConfiguration(
          route: '/history/what_next/not_so_fast',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ContentSlideTemplate(
      title: Text('Well... Not So Fast'),
      insetSecondaryContent: true,
      mainContent: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 32,
        children: [
          Flexible(
            child: FittedBox(
              clipBehavior: Clip.hardEdge,
              child: Image.asset('assets/aero.jpg'),
            ),
          ),
          Flexible(
            child: FittedBox(
              clipBehavior: Clip.hardEdge,
              fit: BoxFit.cover,
              child: Video(
                assetKey: 'assets/scrolling.mp4',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NotSoFastSlide2 extends FlutterDeckSlideWidget {
  NotSoFastSlide2({super.key})
    : super(
        configuration: FlutterDeckSlideConfiguration(
          route: '/history/what_next/not_so_fast2',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ContentSlideTemplate(
      title: Text('Well... Not So Fast'),
      insetSecondaryContent: true,
      mainContent: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 32,
        children: [
          Flexible(
            flex: 2,
            child: FittedBox(
              clipBehavior: Clip.hardEdge,
              fit: BoxFit.cover,
              child: Video(
                assetKey: 'assets/wobbly_windows.mp4',
              ),
            ),
          ),
          Flexible(
            child: FittedBox(
              clipBehavior: Clip.hardEdge,
              child: Image.asset('assets/bump_top.png'),
            ),
          ),
        ],
      ),
    );
  }
}
