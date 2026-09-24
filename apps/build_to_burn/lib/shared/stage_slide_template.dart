import 'package:build_to_burn/shared/entrance.dart';
import 'package:build_to_burn/shared/slide_frame.dart';
import 'package:build_to_burn/shared/style.dart';
import 'package:flutter/material.dart';
import 'package:wnma_talk/wnma_talk.dart';

/// A title and one lead sentence on the left, and a stage for a
/// visualization on the right.
///
/// Until a slide's visualization exists, [stage] defaults to a labeled
/// placeholder.
class StageSlideTemplate extends FlutterDeckSlideWidget {
  const StageSlideTemplate({
    required this.section,
    required this.title,
    required this.lead,
    this.stage,
    super.key,
  });

  /// The talk section, shown in the top bar, e.g. `02 · Frame pipeline`.
  final String section;

  final String title;

  /// One or two sentences.
  final String lead;

  final Widget? stage;

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) {
        final p = Palette.of(context);
        return SlideFrame(
          label: section,
          child: Entrance(
            count: 3,
            builder: (context, reveal) => Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      reveal(0, Text(title, style: p.display)),
                      const SizedBox(height: 36),
                      reveal(1, Text(lead)),
                    ],
                  ),
                ),
                const SizedBox(width: 96),
                Expanded(
                  flex: 4,
                  child: reveal(
                    2,
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
