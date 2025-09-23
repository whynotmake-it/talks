import 'package:flutter/cupertino.dart';
import 'package:physical_ui/slides/history/slides/flat_transition_slide.dart';
import 'package:wnma_talk/animated_visibility.dart';
import 'package:wnma_talk/content_slide_template.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/video.dart';
import 'package:wnma_talk/wnma_talk.dart';

final flatSlides = [FlatDesignSlide(), FlatTransitionSlide()];

class FlatDesignSlide extends FlutterDeckSlideWidget {
  FlatDesignSlide({super.key})
    : super(
        configuration: FlutterDeckSlideConfiguration(
          route: '/history/what_next/flat_design',
          speakerNotes: timSlideNotesHeader,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ContentSlideTemplate(
      mainContent: Row(
        spacing: 32,
        children: [
          Flexible(
            flex: 0,
            child: FittedBox(
              child: AnimatedVisibility(
                child: Video(
                  assetKey: 'assets/windows_phone.mp4',
                  assumedSize: Size(934, 1694),
                ),
              ),
            ),
          ),
          Flexible(
            flex: 0,
            child: FittedBox(
              child: AnimatedVisibility(
                child: Image.asset('assets/ios_7.webp'),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 32,
              children: [
                Expanded(
                  child: AnimatedVisibility(
                    stagger: 3,
                    child: FittedBox(
                      clipBehavior: Clip.hardEdge,
                      child: Image.asset('assets/flat_layout.png'),
                    ),
                  ),
                ),
                Expanded(
                  child: AnimatedVisibility(
                    stagger: 3,
                    child: FittedBox(
                      clipBehavior: Clip.hardEdge,
                      child: Image.asset('assets/flat_layers.png'),
                    ),
                  ),
                ),
              ],
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
