import 'package:build_to_burn/shared/slide_frame.dart';
import 'package:build_to_burn/shared/style.dart';
import 'package:build_to_burn/visualizations/frame_pipeline.dart';
import 'package:flutter/material.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart';

class ColdOpenSlide extends FlutterDeckSlideWidget {
  ColdOpenSlide({super.key})
    : super(
        configuration: FlutterDeckSlideConfiguration(
          route: '/cold-open',
          title: 'Cold open',
          steps: FrameStage.values.length,
          speakerNotes: _notes,
        ),
      );

  static const _notes =
      '''
$timSlideNotesHeader
Key message: a frame goes build -> layout -> paint -> new Scene -> raster -> GPU -> display. DevTools sees the left half well. The right half is where phones get hot.
- One step per stage; the caption under the lanes says what happens.
- Dart runs on the platform main thread on iOS and Android (default since 3.29, mandatory now); the raster thread is separate (Guide 4).
- Every scheduled frame sends a new Scene on stable 3.47.5, even if nothing repainted (Guide 2).
- The raster thread replays the whole frame; a BackdropFilter blur adds a pass break and 3 blur passes on the GPU (Guide 5, 6.2).
- The DevTools raster bar is raster-thread CPU time, not GPU time (Guide 9.1).
- Timings on the strip are illustrative.''';

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) {
        final p = Palette.of(context);
        return SlideFrame(
          label: 'Section 0',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('One frame, stage by stage', style: p.title),
              const SizedBox(height: 40),
              Expanded(
                child: FlutterDeckSlideStepsBuilder(
                  builder: (context, step) =>
                      FramePipeline(stage: FrameStage.values[step - 1]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
