import 'package:build_to_burn/shared/entrance.dart';
import 'package:build_to_burn/shared/slide_frame.dart';
import 'package:build_to_burn/shared/style.dart';
import 'package:flutter/material.dart';
import 'package:wnma_talk/wnma_talk.dart';

class TitleSlide extends FlutterDeckSlideWidget {
  const TitleSlide({super.key})
    : super(
        configuration: const FlutterDeckSlideConfiguration(
          route: '/title',
          title: 'Title',
          speakerNotes: 'Placeholder title. Final title TBD.',
        ),
      );

  static const _stages = [
    'Build',
    'Layout',
    'Paint',
    'Composite',
    'Rasterize',
  ];

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) {
        final p = Palette.of(context);
        return SlideFrame(
          child: Entrance(
            count: 5,
            builder: (context, reveal) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                reveal(
                  0,
                  Text('FLUTTERCON 2026 · LIGHTNING TALK', style: p.eyebrow),
                ),
                const SizedBox(height: 40),
                reveal(1, Text('From build\nto burn', style: p.hero)),
                const SizedBox(height: 40),
                reveal(
                  2,
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: const Text(
                      'Following one slow Flutter frame from the UI thread '
                      'to real GPU work, and what it costs.',
                    ),
                  ),
                ),
                const Spacer(),
                reveal(
                  3,
                  Row(
                    children: [
                      for (final (index, stage) in _stages.indexed) ...[
                        if (index > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                            ),
                            child: Icon(
                              Icons.arrow_forward,
                              size: 28,
                              color: p.textTertiary,
                            ),
                          ),
                        _StageChip(stage, highlighted: index >= 3),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 56),
                reveal(
                  4,
                  Text(
                    'Jesper Bellenbaum & Tim Lehmann · whynotmake.it',
                    style: p.title.copyWith(color: p.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip(this.label, {required this.highlighted});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: BoxDecoration(
        color: highlighted ? p.accentSoft : p.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: highlighted ? p.accent : p.border,
          width: 2,
        ),
      ),
      child: Text(
        label,
        style: mono(28, weight: 500, color: highlighted ? p.accent : p.text),
      ),
    );
  }
}
