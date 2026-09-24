import 'package:build_to_burn/shared/slide_frame.dart';
import 'package:build_to_burn/shared/style.dart';
import 'package:build_to_burn/visualizations/blur_scenario.dart';
import 'package:build_to_burn/visualizations/paint_vs_composite.dart';
import 'package:flutter/material.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart';

class PaintVsCompositeSlide extends FlutterDeckSlideWidget {
  PaintVsCompositeSlide({super.key})
    : super(
        configuration: FlutterDeckSlideConfiguration(
          route: '/paint-vs-composite',
          title: 'Paint vs composite',
          steps: BlurScenario.ahaSequence.length,
          speakerNotes: _notes,
        ),
      );

  static const _notes =
      '''
$timSlideNotesHeader
Key message: answer to the vote: C makes the frames, A makes each one expensive. GPU work = how often you draw x how hard each frame is.
- iOS: TextField defaults cursorOpacityAnimates to true; the caret is an AnimationController whose ticker asks for a frame every vsync (60 or 120/s) while focused. Android default: a 500 ms timer, 2 frames/s (Guide 7.2).
- The caret sits in its own repaint boundary: a tick re-records one rect, and nothing during the hold phases.
- On stable, every tick still sends a new Scene, and the raster thread re-renders the whole screen with the blur: pass break + 3 blur passes, 120 times a second.
- Each frame fits the budget, so no jank; the GPU just never idles. Heat builds, then throttling causes jank.
- Myth-buster: RepaintBoundary and const save UI-thread work, not GPU work, under Impeller.
- "A frame requested is not a frame rendered": flutter/flutter#192128 (master) skips ticks where nothing repainted. Helps the caret during holds, not spinners. Name it as coming unless it has reached stable.
- It's a defaults problem, not "your code is wrong".
- Pass counts are per Impeller source; count them in a Metal capture before quoting.''';

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) {
        final p = Palette.of(context);
        return SlideFrame(
          label: 'Section 3',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Paint vs composite', style: p.title),
              const SizedBox(height: 40),
              Expanded(
                child: FlutterDeckSlideStepsBuilder(
                  builder: (context, step) => PaintVsComposite(
                    scenario: BlurScenario.ahaSequence[step - 1],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
