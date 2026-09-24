import 'package:build_to_burn/design/blinking_caret.dart';
import 'package:build_to_burn/design/style.dart';
import 'package:build_to_burn/templates/section_slide_template.dart';
import 'package:flutter/material.dart';
import 'package:wnma_talk/wnma_talk.dart';

/// One placeholder opener per section. Content comes from the research
/// tracks.
const sectionSlides = [
  SectionSlideTemplate(
    number: 1,
    label: 'Hook',
    title: 'One blinking cursor',
    lead:
        'A search sheet kept the GPU at 100%, all the time. The cause was '
        'its blinking cursor. Where does that cost come from? Vote now; '
        'we resolve it later.',
    stage: _SearchFieldStage(),
    configuration: FlutterDeckSlideConfiguration(
      route: '/hook',
      title: 'Hook: the blinking cursor',
      speakerNotes:
          'The ClickUp case. Pose it as a vote, resolve it after section 3.',
    ),
  ),
  SectionSlideTemplate(
    number: 2,
    label: 'Frame pipeline',
    title: 'One frame, five stages',
    lead:
        'Build, layout, paint, composite, rasterize. Which of them run on the '
        'UI thread, and which on the raster thread and the GPU.',
    configuration: FlutterDeckSlideConfiguration(
      route: '/frame-pipeline',
      title: 'Frame pipeline',
    ),
  ),
  SectionSlideTemplate(
    number: 3,
    label: 'Painting vs compositing',
    title: 'Painting vs compositing',
    lead:
        'How render objects create engine layers, how those layers are '
        'handed to the engine, and how they become GPU draw calls.',
    configuration: FlutterDeckSlideConfiguration(
      route: '/painting-vs-compositing',
      title: 'Painting vs compositing',
      speakerNotes: 'Resolve the hook vote here.',
    ),
  ),
  SectionSlideTemplate(
    number: 4,
    label: 'GPU profiling',
    title: 'Seeing the real GPU work',
    lead:
        'An Xcode Metal frame capture on iOS, and how the same investigation '
        'maps to Android GPU Inspector and Perfetto.',
    configuration: FlutterDeckSlideConfiguration(
      route: '/gpu-profiling',
      title: 'GPU profiling',
    ),
  ),
  SectionSlideTemplate(
    number: 5,
    label: 'Fixes',
    title: 'Cutting the cost',
    lead:
        'Concrete ways to reduce blurs, saveLayer, shaders and overdraw in '
        'real apps.',
    configuration: FlutterDeckSlideConfiguration(
      route: '/fixes',
      title: 'Fixes',
    ),
  ),
  SectionSlideTemplate(
    number: 6,
    label: 'Production + AI skill',
    title: 'Production, and an AI skill',
    lead:
        'Watching frame timing in production, and a Claude Code skill that '
        'reads a trace and explains it.',
    configuration: FlutterDeckSlideConfiguration(
      route: '/production',
      title: 'Production + AI skill',
    ),
  ),
];

/// A search field with a focused, blinking cursor: the hook's culprit.
class _SearchFieldStage extends StatelessWidget {
  const _SearchFieldStage();

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.all(64),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 112,
            padding: const EdgeInsets.symmetric(horizontal: 36),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: p.accent, width: 3),
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 44, color: p.textTertiary),
                const SizedBox(width: 24),
                Text('Search', style: p.title.copyWith(color: p.text)),
                const SizedBox(width: 4),
                const BlinkingCaret(height: 52, width: 4),
              ],
            ),
          ),
          const SizedBox(height: 48),
          Text('GPU', style: p.eyebrow),
          const SizedBox(height: 16),
          Container(height: 24, color: p.accent),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Text('100%', style: mono(40, weight: 600, color: p.text)),
          ),
        ],
      ),
    );
  }
}
