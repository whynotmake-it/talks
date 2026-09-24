import 'package:build_to_burn/shared/slide_frame.dart';
import 'package:build_to_burn/shared/style.dart';
import 'package:flutter/material.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart';

/// A throwaway placeholder that holds an agenda section's place in the
/// deck: a plain title, and the facts in the speaker notes.
///
/// Replace these with real slides. Nothing here is a layout to build on.
class SkeletonSlide extends FlutterDeckSlideWidget {
  const SkeletonSlide({
    required this.section,
    required this.title,
    required super.configuration,
    super.key,
  });

  /// The agenda section, e.g. `2a`.
  final String section;

  final String title;

  @override
  Widget build(BuildContext context) {
    return FlutterDeckSlide.custom(
      builder: (context) {
        final p = Palette.of(context);
        return SlideFrame(
          label: 'Section $section',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: p.display),
              const SizedBox(height: 32),
              Text(
                'Skeleton. Content and layout come later; the facts are in '
                'the speaker notes.',
                style: p.caption,
              ),
            ],
          ),
        );
      },
    );
  }
}

const fixesSlide = SkeletonSlide(
  section: '6',
  title: 'Fixes: idle screens and animating screens',
  configuration: FlutterDeckSlideConfiguration(
    route: '/fixes',
    title: 'Fixes',
    speakerNotes:
        '''
$jesperSlideNotesHeader
Key message: kill idle frames first, then make each frame cheaper.
- Fewer frames: cursorOpacityAnimates: false (iOS caret 60-120 -> 2 frames/s), no autofocus, TickerMode(enabled: false) on the page under a sheet, stop hidden spinners (Guide 10).
- The main fix is stopping or slowing the ticker; it works for spinners and any per-frame painter. flutter/flutter#192128 (framework-side drawFrame gate, expected in 3.50 stable) is only partial: it skips frames where a ticker runs but nothing paints (the caret's hold ticks), not a spinner that paints every tick, even inside a RepaintBoundary.
- fixed_ticker, and natively motor 2.0: tickerRate: on every motor widget, TickerRateScope for a subtree (rivership #320). It cuts frame count, not cost per frame. The fastest ticker on screen sets the frame rate; framework tickers (caret, Material spinners) ignore the scope (Guide 10.1).
- Cheaper frames: BackdropGroup + BackdropFilter.grouped, clip every blur tightly, ImageFiltered for a known child, sigma on the sawtooth, BackdropFilter(enabled: false) when covered or during drag, snapshot blur only over static content.
- RepaintBoundary around spinners saves UI-thread work only under Impeller.
- Keep the blur: degradation ladder by thermal state: live blur, tightly clipped -> grouped -> lighter (smaller region, sawtooth sigma, off during drag) -> snapshot blur -> tinted scrim (Guide 10.2).''',
  ),
);

const productionSlide = SkeletonSlide(
  section: '7',
  title: 'Production, and a skill that reads the trace',
  configuration: FlutterDeckSlideConfiguration(
    route: '/production',
    title: 'Production + AI skill',
    speakerNotes:
        '''
$timSlideNotesHeader
Key message: log idle frames per second in production; let /frame-autopsy read the trace.
- FrameTiming (addTimingsCallback) sees UI and raster CPU time, never the GPU. Sentry times the UI thread only; Datadog reports build and raster; MetricKit MXGPUMetric is a rare field GPU signal (Guide 11.1).
- Best metric for this talk: idle frames per second (no input for ~2 s). Healthy ~ 0; the search sheet sits at the refresh rate.
- Also: raster-dominant jank, raster floor on idle frames, thermal slope. The budget moves when iOS caps 120 -> 60 Hz.
- /frame-autopsy: scripts count (Perfetto SQL), the model explains a small findings file, and it names which frame to capture (Guide 11.2).
- Recorded skill run: verdict on the before trace, compare mode on the after trace.''',
  ),
);

const closeSlide = SkeletonSlide(
  section: '8',
  title: 'The Monday checklist',
  configuration: FlutterDeckSlideConfiguration(
    route: '/close',
    title: 'Close',
    speakerNotes:
        '''
$jesperSlideNotesHeader
Key message: three takeaways.
1. GPU work = frames x cost per frame.
2. DevTools shows the symptom; platform tools show the cost.
3. Kill idle frames first (cursor, TickerMode, fixed_ticker / motor 2.0), then make each frame cheaper.
- Checklist ranked by effort: flags first, snapshot blur last.
- QR code to the interactive deck, the onboarding doc and the skill repo.''',
  ),
);
