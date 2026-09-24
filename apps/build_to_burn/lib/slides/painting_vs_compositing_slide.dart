import 'package:build_to_burn/shared/stage_slide_template.dart';
import 'package:flutter/widgets.dart';
import 'package:wnma_talk/wnma_talk.dart';

class PaintingVsCompositingSlide extends FlutterDeckSlideWidget {
  const PaintingVsCompositingSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/painting-vs-compositing',
          title: 'Painting vs compositing',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return const StageSlideTemplate(
      section: '03 · Painting vs compositing',
      title: 'Painting vs compositing',
      lead:
          'How render objects create engine layers, how those layers are '
          'handed to the engine, and how they become GPU draw calls.',
    );
  }
}
