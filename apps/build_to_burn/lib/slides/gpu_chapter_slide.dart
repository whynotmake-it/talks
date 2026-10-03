import 'package:build_to_burn/shared/slide_frame.dart';
import 'package:build_to_burn/shared/style.dart';
import 'package:build_to_burn/visualizations/gpu_frame.dart';
import 'package:flutter/material.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart';

/// The GPU chapter: how the GPU paints the demo frame, and why its backdrop
/// blur sends the picture to memory and back, one beat per step.
class GpuChapterSlide extends FlutterDeckSlideWidget {
  const GpuChapterSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/gpu',
          title: 'On the GPU',
          steps: 8,
          speakerNotes: jesperSlideNotesHeader,
        ),
      );

  static const _captions = {
    GpuBeat.start: "Now we're on the GPU.",
    GpuBeat.paint: 'The GPU paints many pixels at the same time.',
    GpuBeat.needs:
        'Could the blur be painted now? Part of what it needs is missing.',
    GpuBeat.finish:
        "So the GPU first finishes everything behind it. That's one pass.",
    GpuBeat.store: 'The pass ends, and the picture goes to memory.',
    GpuBeat.read:
        'The blur reads it and writes a blurred copy, also in memory.',
    GpuBeat.back:
        'A new pass paints it all again, with the blurred copy on top.',
    GpuBeat.repeat: 'This round trip is the expensive part, on every frame.',
  };

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) => SlideFrame(
        padding: const EdgeInsets.fromLTRB(80, 0, 80, 24),
        child: FlutterDeckSlideStepsBuilder(
          builder: (context, step) {
            final beat =
                GpuBeat.values[(step - 1).clamp(
                  0,
                  GpuBeat.values.length - 1,
                )];
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
