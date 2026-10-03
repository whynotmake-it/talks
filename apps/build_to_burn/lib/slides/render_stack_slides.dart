import 'package:build_to_burn/slides/render_stack_slide.dart';
import 'package:build_to_burn/visualizations/render_stack/render_stack_content.dart';
import 'package:build_to_burn/visualizations/render_stack/render_stack_model.dart';
import 'package:wnma_talk/slide_number.dart';
import 'package:wnma_talk/wnma_talk.dart' show FlutterDeckTransition;

// The slides that show the render stack: one per build-up step of
// docs/render-stack-visualization.md that has shipped. Consecutive stack
// slides are chained: each animates from the previous slide's last view
// (forward) or the next slide's first view (backward), with the deck's own
// transition off so the morph runs seamlessly across slides.

RenderStackSlide _stackSlide(
  String route,
  String title,
  List<RenderStackStep> script, {
  required String speakerNotes,
  RenderStackView? entry,
  RenderStackView? backEntry,
}) => RenderStackSlide(
  route: route,
  title: title,
  script: script,
  entry: entry,
  backEntry: backEntry,
  transition: const FlutterDeckTransition.none(),
  speakerNotes: speakerNotes,
);

final coldOpenSlide = RenderStackSlide(
  route: '/cold-open',
  title: 'Cold open',
  script: coldOpenScript,
  backEntry: hookScript.last.view,
  speakerNotes:
      '''
$timSlideNotesHeader
Key message: you all write this. The spec's Demo widget: a blue page, a frosted card (ClipRRect r=24 + BackdropFilter blur 10) and a focused CupertinoTextField.
- Just the code, full screen, plain editor look. No stack yet; the hook (phone + vote) comes next.
- In 2a this slide returns and shrinks into plane 1, and the stack grows one stage at a time (spec section 7.1).
''',
);

final hookSlide = RenderStackSlide(
  route: '/hook',
  title: 'Hook',
  script: hookScript,
  entry: coldOpenScript.last.view,
  backEntry: codeStep.view,
  transition: const FlutterDeckTransition.none(),
  speakerNotes:
      '''
$jesperSlideNotesHeader
Key message: a search sheet over the app drove the GPU to its limit and never let it rest. Pose it as a vote and leave it open.
- The cold open's code slides into the left column as the demo's phone and the vote come in on the right: code on the left, UI + vote on the right.
- Vote: A) the blur, B) the list underneath, C) the blinking cursor, D) the keyboard.
- The sheet is a frosted BackdropFilter blur over a busy page, with a focused field.
- Show one real measurement with a footer: device + SoC, OS, Flutter version, --profile, 60/120 Hz, thermal state, duration, runs, metric source (Guide 9.2). No bare "GPU %".
- The code stays when the vote ends: the next slide continues straight from this layout.
- Answer comes in section 3: C makes the frames, A makes each one expensive.
- Get ClickUp's sign-off and facts (Flutter version, sheet widget, cursorOpacityAnimates, platform views?) before telling it (Guide 14).''',
);

// § 2a, UI half: code → colors, then one slide per stage. Moving on from a
// stage lands it on the stack while the next stage's slide comes in.

final codeSlide = _stackSlide(
  '/pipeline-code',
  layerHeading(1),
  [codeStep],
  entry: hookScript.last.view,
  backEntry: colorsStep.view,
  speakerNotes:
      '''
$timSlideNotesHeader
The slide opens on the hook's layout: the code slides from the left column back to full screen as the phone and vote fade.
Key message for the UI half: painting records, layers group, and every scheduled frame sends a new Scene, even if nothing repainted (stable).''',
);

final colorsSlide = _stackSlide(
  '/pipeline-colors',
  layerHeading(1, 'Widgets by color'),
  [colorsStep],
  entry: codeStep.view,
  backEntry: stage2Step.view,
  speakerNotes:
      '''
$timSlideNotesHeader
Color coding: each widget's constructor calls are marked in the color of the render objects it creates. Positioned.fill creates no render object (dashed neutral mark). Container creates three (RenderConstrainedBox, _RenderColoredBox, RenderPositionedBox). CupertinoTextField creates 22.''',
);

final stage2Slide = _stackSlide(
  '/stage-2',
  layerHeading(2),
  [stage2Step],
  entry: colorsStep.view,
  backEntry: stage3Step.view,
  speakerNotes:
      '''
$timSlideNotesHeader
On the way in: The code slide lands as plane 1: it simplifies in place, then its corners spring to the plane's rhombus.
Left the widget tree, right the render objects it creates — same colors. Layout sizes them: 393×852 for the page, 300×120 for the card.''',
);

final stage3Slide = _stackSlide(
  '/stage-3',
  layerHeading(3),
  [stage3Step],
  entry: stage2Step.view,
  backEntry: stage4Step.view,
  speakerNotes:
      '''
$timSlideNotesHeader
On the way in: Plane 2 lands: laid-out render tree. markNeedsPaint walks up to the nearest repaint boundary; that boundary re-records its subtree (Guide 3.3).
- paint() records a Picture (a DisplayList), a tape of draw commands. Nothing is drawn yet (Guide 3.1).
- Pushing a layer ends the current picture; the next draw starts a new one. The ClipRRect clip becomes a ClipRRectLayer only because the BackdropFilter below it needs compositing. A BackdropFilter always gets a BackdropFilterLayer (Guide 3.2).''',
);

final stage4Slide = _stackSlide(
  '/stage-4',
  layerHeading(4),
  [stage4Step],
  entry: stage3Step.view,
  backEntry: stage5Step.view,
  speakerNotes:
      '''
$timSlideNotesHeader
On the way in: Plane 3 lands: pictures and pushed layers.
- pushLayer appends into the layer tree while paint runs: paint builds the layer tree directly, there is no separate "build the layer tree" pass.
- The slide's layer tree omits the field's LeaderLayers and an empty background-painter picture.''',
);

final stage5Slide = _stackSlide(
  '/stage-5',
  layerHeading(5),
  [stage5Step],
  entry: stage4Step.view,
  backEntry: stage6Step.view,
  speakerNotes:
      '''
$timSlideNotesHeader
On the way in: Plane 4 lands: layer tree.
- compositeFrame describes the layer tree to the engine as a new Scene, once per frame per view. Clean subtrees are addRetained. Cheap (Guide 3.4).
- "Retained" saves UI-thread work only; the GPU still draws that subtree.''',
);

// § 2b, raster half.

final stage6Slide = _stackSlide(
  '/stage-6',
  layerHeading(6),
  [stage6Step],
  entry: stage5Step.view,
  backEntry: stage7Step.view,
  speakerNotes:
      '''
$jesperSlideNotesHeader
On the way in: Plane 5 lands: one Scene, handed across the thread border to the raster thread.
Key message: the raster thread flattens the tree into one DisplayList and replays all of it every frame. Draw calls are cheap, passes are costly.
- One DisplayList per view per frame (per slice with platform views). No raster cache under Impeller (Guide 5).
- Partial repaint is off on mobile Impeller: never on Android, forced off on iOS by the external view embedder. Scope: "mobile Impeller, no platform views".''',
);

final stage7Slide = _stackSlide(
  '/stage-7',
  layerHeading(7),
  [stage7Step],
  entry: stage6Step.view,
  backEntry: stage8Step.view,
  speakerNotes:
      '''
$jesperSlideNotesHeader
On the way in: Plane 6 lands: one DisplayList.
- saveLayer (ShaderMask, ColorFiltered, non-peephole Opacity): +1 offscreen pass, pasted back as "Subpass" (Guide 6.2 B).
- BackdropFilter blur: ends the parent pass, 3 blur passes (downsample, vertical, horizontal), restarts the pass with a full-screen "MSAA backdrop" redraw and replays clips. About 4-5 extra passes; count them in a capture (Guide 6.2 C).
- BackdropGroup / BackdropFilter.grouped shares one capture (and one blur if equal) (Guide 6.2).''',
);

final stage8Slide = _stackSlide(
  '/stage-8',
  layerHeading(8),
  [stage8Step],
  entry: stage7Step.view,
  backEntry: backpressureStep.view,
  speakerNotes:
      '''
$jesperSlideNotesHeader
On the way in: Plane 7 lands: command buffers. Work crosses the GPU border at commit.
Plane 8: the GPU fills tiles on-chip; the blur's pass break is paid here, every frame.''',
);

final backpressureSlide = _stackSlide(
  '/backpressure',
  'Back-pressure',
  [backpressureStep],
  entry: stage8Step.view,
  backEntry: stage9Step.view,
  speakerNotes:
      '''
$jesperSlideNotesHeader
On the way in: Plane 8 lands: finished drawable.
Back-pressure: the raster thread waits for a drawable, and DevTools counts that wait as raster time.''',
);

final stage9Slide = _stackSlide(
  '/stage-9',
  layerHeading(9),
  [stage9Step],
  entry: backpressureStep.view,
  backEntry: framesStep.view,
  speakerNotes:
      '''
$jesperSlideNotesHeader
Plane 9: the drawable is presented. FlutterMetalLayer keeps 3 drawables.''',
);

final framesSlide = _stackSlide(
  '/frames-in-flight',
  'Frames in flight',
  [framesStep],
  entry: stage9Step.view,
  backEntry: limitsStep.view,
  speakerNotes:
      '''
$jesperSlideNotesHeader
On the way in: Plane 9 lands: pixels on screen.
Frames in flight (spec section 6): N+1 on the UI planes while N is on raster, N-1 on GPU/display; the 2-slot queue and 3 drawables.''',
);

final limitsSlide = _stackSlide(
  '/flight-limits',
  'Pipeline limits',
  [limitsStep],
  entry: framesStep.view,
  backEntry: bandsStep.view,
  speakerNotes:
      '''
$jesperSlideNotesHeader
What doesn't overlap: one UI thread, one raster thread, dependent passes; the helper threads that do overlap (spec section 6).''',
);

final bandsSlide = _stackSlide(
  '/stack-bands',
  'Zoom out',
  [bandsStep],
  entry: limitsStep.view,
  backEntry: ahaScript.first.view,
  speakerNotes:
      '''
$jesperSlideNotesHeader
The five-band zoom-out: your code, UI thread, the handoff, raster thread, GPU and display.''',
);

final ahaSlide = RenderStackSlide(
  route: '/paint-vs-composite',
  title: 'Paint vs composite',
  script: ahaScript,
  entry: bandsStep.view,
  backEntry: blurCostScript.first.view,
  transition: const FlutterDeckTransition.none(),
  speakerNotes:
      '''
$timSlideNotesHeader
Key message: answer to the vote: C makes the frames, A makes each one expensive. A running Ticker means a full frame every vsync, whether or not anything repaints. GPU work = how often you draw x how hard each frame is.
- The focused iOS field's caret runs on an AnimationController. While its Ticker runs, it requests a frame every vsync: 120 a second at ProMotion (measured ~119 Scenes/s in the demo's widget test; one vsync per 1.017 s blink cycle has no frame scheduled).
- Every one of those frames builds a new Scene, and the raster thread and GPU re-render the whole screen with the blur: pass break + 3 blur passes (stable 3.47.5).
- Repaints are the small part: the caret's pixels change on ~8 frames per second (8 per blink cycle, measured). The other ~111 frames per second repaint nothing and still cost the full raster + GPU work.
- Each frame fits the budget, so no jank; the GPU just never idles. Heat builds, then throttling causes jank.
- Myth-buster: RepaintBoundary and const save UI-thread paint work, not frames, and not GPU work under Impeller.
- "A frame requested is not a frame rendered", but only partly: flutter/flutter#192128 is a partial, framework-side skip (a gate in RendererBinding.drawFrame, needsCompositeFrame). It skips frames where a ticker runs but nothing paints: no Scene, nothing reaches the engine. Measured on master: the caret drops from ~119 to ~7.9 Scenes/s. Merged 2026-09-24 after the 3.49 beta cut: expected in 3.50 stable (estimate).
- What it does not fix: anything that paints every frame. A custom spinner inside a RepaintBoundary paints one small picture per tick (cheap on the UI thread), but that still marks the frame dirty, so the full composite, full-screen raster and every blur run every vsync. Its arc (S) keeps pulsing at full rate after the caret's is cut.
- The main fix is to stop or slow the ticker: TickerMode(enabled: false) on the page under a sheet and on hidden tabs, pause animations offscreen, cursorOpacityAnimates: false (a 2/s timer instead of a ticker), fixed_ticker / motor 2.0 tickerRate for your own animations.
- It's a defaults problem, not "your code is wrong".
- On the list: loop T (Ticker frame) is the bold bracket from the vsync row, dim through rows 1-4 (nothing dirty) and hot from the Scene up, labelled ≈119 frames/s, ≈111 repaint nothing. Repaint C (≈8/s) is a thin bracket. Rows and planes light up together. Pulses run slowed x10.
''',
);

final blurCostSlide = RenderStackSlide(
  route: '/blur-cost',
  title: 'Why blur costs',
  script: blurCostScript,
  entry: ahaScript.last.view,
  backEntry: profilingScript.first.view,
  transition: const FlutterDeckTransition.none(),
  speakerNotes:
      '''
$jesperSlideNotesHeader
Key message: BackdropFilter blur is everywhere and shockingly expensive for how common it is, paid every frame.
- A stock CupertinoNavigationBar and CupertinoTabBar each blur by default (their default background isn't opaque): two backdrop blurs you never wrote.
- Mobile GPUs render in on-chip tiles. A backdrop read forces the pass to resolve and store to DRAM; the next pass is re-seeded with a full-screen redraw plus clips; 3 blur passes run (Guide 8).
- DRAM costs roughly 10x more energy per byte than on-chip memory. Estimate (label it): ~12 MB full-screen texture, ~24-36 MB per blur per frame, ~3-4 GB/s at 120 Hz. Prefer measured Metal counters.
- A GPU woken every vsync never clocks down or idles. No jank is not no cost; heat builds over minutes.
- Sigma is a sawtooth: <= 4 full resolution, above that downsampled; the fixed cost stays.
- On the stack: the GPU tier's tiles fill on-chip, the pass snaps and T0 streams to DRAM, then the resumed pass is re-seeded from it (spec step 7; the camera dolly is not built).
- T0 is an estimate: 1179×2556 RGBA8 is about 12 MB.
- One line on liquid glass: the Flutter team is officially building it; any liquid-glass look is built on the same backdrop reads, so all of this applies, multiplied.''',
);

final profilingSlide = RenderStackSlide(
  route: '/profiling',
  title: 'Profiling',
  script: profilingScript,
  entry: blurCostScript.last.view,
  transition: const FlutterDeckTransition.none(),
  speakerNotes:
      '''
$timSlideNotesHeader
Key message: DevTools shows the symptom; platform tools show the cost.
- Step 1, no Xcode: DevTools bars that keep coming while idle, tiny UI bar, busy raster bar = the pipeline never sleeps. debugPrintScheduleFrameStacks names who asks for frames.
- The DevTools raster bar is CPU time on the raster thread, not GPU time (Guide 9.1).
- Step 2: Instruments Metal System Trace shows a GPU command buffer every vsync while idle; Power Profiler shows the power impact.
- Step 3 (live): Xcode Metal frame capture, scope "Impeller Frame", Profile config. Dependencies graph: "EntityPass" passes, "MSAA backdrop", "Gaussian Blur Filter". Capture timings are replay timings: structure, not cost (Guide 9.5).
- Fallbacks: a .gputrace from the same iPhone, then a video. Never capture the macOS deck.
- Android: Perfetto + AGI/APA; stock-engine passes are unlabeled; the trigger there is a spinner or a blur, not the caret (Android caret: 2 frames/s).''',
);
