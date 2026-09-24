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

const hookSlide = SkeletonSlide(
  section: '1',
  title: 'Hook: the search sheet',
  configuration: FlutterDeckSlideConfiguration(
    route: '/hook',
    title: 'Hook',
    speakerNotes:
        '''
$jesperSlideNotesHeader
Key message: a search sheet over the app drove the GPU to its limit and never let it rest. Pose it as a vote and leave it open.
- Vote: A) the blur, B) the list underneath, C) the blinking cursor, D) the keyboard.
- The sheet is a frosted BackdropFilter blur over a busy page, with a focused field.
- Show one real measurement with a footer: device + SoC, OS, Flutter version, --profile, 60/120 Hz, thermal state, duration, runs, metric source (Guide 9.2). No bare "GPU %".
- Answer comes in section 3: C makes the frames, A makes each one expensive.
- Get ClickUp's sign-off and facts (Flutter version, sheet widget, cursorOpacityAnimates, platform views?) before telling it (Guide 14).''',
  ),
);

const blurCostSlide = SkeletonSlide(
  section: '4',
  title: 'Why an everyday blur costs so much',
  configuration: FlutterDeckSlideConfiguration(
    route: '/blur-cost',
    title: 'Why blur costs',
    speakerNotes:
        '''
$jesperSlideNotesHeader
Key message: BackdropFilter blur is everywhere and shockingly expensive for how common it is, paid every frame.
- A stock CupertinoNavigationBar and CupertinoTabBar each blur by default (their default background isn't opaque): two backdrop blurs you never wrote.
- Mobile GPUs render in on-chip tiles. A backdrop read forces the pass to resolve and store to DRAM; the next pass is re-seeded with a full-screen redraw plus clips; 3 blur passes run (Guide 8).
- DRAM costs roughly 10x more energy per byte than on-chip memory. Estimate (label it): ~12 MB full-screen texture, ~24-36 MB per blur per frame, ~3-4 GB/s at 120 Hz. Prefer measured Metal counters.
- A GPU woken every vsync never clocks down or idles. No jank is not no cost; heat builds over minutes.
- Sigma is a sawtooth: <= 4 full resolution, above that downsampled; the fixed cost stays.
- One line on liquid glass: the Flutter team is officially building it; any liquid-glass look is built on the same backdrop reads, so all of this applies, multiplied.''',
  ),
);

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
