import 'package:build_to_burn/shared/slide_frame.dart';
import 'package:build_to_burn/shared/style.dart';
import 'package:build_to_burn/visualizations/gpu_frame.dart';
import 'package:flutter/material.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart';

/// The GPU chapter: how the GPU paints the demo frame, and why its backdrop
/// blur sends the picture to memory and back, one beat per step. Shows one
/// frame; the round trip on every frame comes later in the talk.
class GpuChapterSlide extends FlutterDeckSlideWidget {
  const GpuChapterSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/gpu',
          title: 'On the GPU',
          steps: 7,
          speakerNotes: timSlideNotesHeader,
        ),
      );

  /// Short titles: the explaining is said, not read.
  static const _captions = {
    GpuBeat.start: 'On the GPU',
    GpuBeat.paint: 'Tiles, in parallel',
    GpuBeat.needs: 'The blur needs its neighbours',
    GpuBeat.finish: 'Pass 1',
    GpuBeat.store: 'Out to memory',
    GpuBeat.read: 'The blur',
    GpuBeat.back: 'Pass 2: back again',
  };

  /// One frame only: the repeat beat waits for the "every frame" slide.
  static final _beats = [
    for (final beat in GpuBeat.values)
      if (beat != GpuBeat.repeat) beat,
  ];

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => SlideFrame(
        padding: const EdgeInsets.fromLTRB(80, 0, 80, 24),
        child: FlutterDeckSlideStepsBuilder(
          builder: (context, step) {
            final beat = _beats[(step - 1).clamp(0, _beats.length - 1)];
            final p = Palette.of(context);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 80,
                  child: Text(
                    _captions[beat]!,
                    maxLines: 1,
                    style: archivo(
                      48,
                      weight: 500,
                      height: 1.25,
                      color: p.text,
                    ),
                  ),
                ),
                Expanded(child: GpuFrame(beat: beat)),
              ],
            );
          },
        ),
      ),
    );
  }
}
