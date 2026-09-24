import 'package:build_to_burn/shared/stage_slide_template.dart';
import 'package:flutter/widgets.dart';
import 'package:wnma_talk/wnma_talk.dart';

class ProductionSlide extends FlutterDeckSlideWidget {
  const ProductionSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/production',
          title: 'Production + AI skill',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return const StageSlideTemplate(
      section: '06 · Production + AI skill',
      title: 'Production, and an AI skill',
      lead:
          'Watching frame timing in production, and a Claude Code skill that '
          'reads a trace and explains it.',
    );
  }
}
