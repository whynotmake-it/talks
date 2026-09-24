import 'package:build_to_burn/shared/blinking_caret.dart';
import 'package:build_to_burn/shared/stage_slide_template.dart';
import 'package:build_to_burn/shared/style.dart';
import 'package:flutter/material.dart';
import 'package:wnma_talk/wnma_talk.dart';

class HookSlide extends FlutterDeckSlideWidget {
  const HookSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/hook',
          title: 'Hook: the blinking cursor',
          speakerNotes:
              'The ClickUp case. Pose it as a vote, resolve it after '
              'painting vs compositing.',
        ),
      );

  @override
  Widget build(BuildContext context) {
    return const StageSlideTemplate(
      section: '01 · Hook',
      title: 'One blinking cursor',
      lead:
          'A search sheet kept the GPU at 100%, all the time. The cause was '
          'its blinking cursor. Where does that cost come from? Vote now; we '
          'resolve it later.',
      stage: _SearchFieldStage(),
    );
  }
}

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
