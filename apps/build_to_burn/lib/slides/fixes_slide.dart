import 'package:build_to_burn/shared/stage_slide_template.dart';
import 'package:flutter/widgets.dart';
import 'package:wnma_talk/wnma_talk.dart';

class FixesSlide extends FlutterDeckSlideWidget {
  const FixesSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/fixes',
          title: 'Fixes',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return const StageSlideTemplate(
      section: '05 · Fixes',
      title: 'Cutting the cost',
      lead:
          'Concrete ways to reduce blurs, saveLayer, shaders and overdraw '
          'in real apps.',
    );
  }
}
