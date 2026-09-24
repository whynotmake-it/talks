import 'package:build_to_burn/shared/stage_slide_template.dart';
import 'package:flutter/widgets.dart';
import 'package:wnma_talk/wnma_talk.dart';

class GpuProfilingSlide extends FlutterDeckSlideWidget {
  const GpuProfilingSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/gpu-profiling',
          title: 'GPU profiling',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return const StageSlideTemplate(
      section: '04 · GPU profiling',
      title: 'Seeing the real GPU work',
      lead:
          'An Xcode Metal frame capture on iOS, and how the same investigation '
          'maps to Android GPU Inspector and Perfetto.',
    );
  }
}
