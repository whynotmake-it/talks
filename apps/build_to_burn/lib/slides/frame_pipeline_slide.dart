import 'package:build_to_burn/shared/stage_slide_template.dart';
import 'package:flutter/widgets.dart';
import 'package:wnma_talk/wnma_talk.dart';

class FramePipelineSlide extends FlutterDeckSlideWidget {
  const FramePipelineSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/frame-pipeline',
          title: 'Frame pipeline',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return const StageSlideTemplate(
      section: '02 · Frame pipeline',
      title: 'One frame, five stages',
      lead:
          'Build, layout, paint, composite, rasterize. Which of them run on '
          'the UI thread, and which on the raster thread and the GPU.',
    );
  }
}
