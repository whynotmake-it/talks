import 'package:build_to_burn/design/entrance.dart';
import 'package:build_to_burn/design/slide_frame.dart';
import 'package:build_to_burn/design/style.dart';
import 'package:flutter/material.dart';
import 'package:wnma_talk/wnma_talk.dart';

/// A section opener: number, title and one lead sentence on the left, and a
/// stage for the section's visualization on the right.
///
/// Until a section's visualization exists, [stage] defaults to a labeled
/// placeholder.
class SectionSlideTemplate extends FlutterDeckSlideWidget {
  const SectionSlideTemplate({
    required this.number,
    required this.label,
    required this.title,
    required this.lead,
    required super.configuration,
    this.stage,
    super.key,
  });

  /// The section's position in the talk, starting at 1.
  final int number;

  /// A short label for the top bar, e.g. `Frame pipeline`.
  final String label;

  final String title;

  /// One or two sentences.
  final String lead;

  final Widget? stage;

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) {
        final p = Palette.of(context);
        final eyebrow = '${number.toString().padLeft(2, '0')} · $label';
        return SlideFrame(
          label: eyebrow,
          child: Entrance(
            count: 4,
            builder: (context, reveal) => Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      reveal(0, Text(eyebrow.toUpperCase(), style: p.eyebrow)),
                      const SizedBox(height: 32),
                      reveal(1, Text(title, style: p.display)),
                      const SizedBox(height: 36),
                      reveal(2, Text(lead)),
                    ],
                  ),
                ),
                const SizedBox(width: 96),
                Expanded(
                  flex: 4,
                  child: reveal(
                    3,
                    Stage(child: stage ?? const _PlaceholderStage()),
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

class _PlaceholderStage extends StatelessWidget {
  const _PlaceholderStage();

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Center(
      child: Text('VISUALIZATION · TBD', style: p.eyebrow),
    );
  }
}
