import 'package:build_to_burn/slides/render_stack_slide.dart';
import 'package:build_to_burn/visualizations/render_stack/render_stack_content.dart';
import 'package:wnma_talk/slide_number.dart';

// The slides that show the render stack, one per build-up step of
// docs/render-stack-visualization.md that has shipped (1-5, 7, 8).

final coldOpenSlide = RenderStackSlide(
  route: '/cold-open',
  title: 'Cold open',
  section: '0',
  script: coldOpenScript,
  speakerNotes:
      '''
$timSlideNotesHeader
Key message: a frame goes build -> layout -> paint -> new Scene -> raster -> GPU -> display. DevTools sees the lower half well. The upper half is where phones get hot.
- Four bands rise (your code, UI thread, raster thread, GPU and display), then one frame travels up as a token showing each tier's output.
- Dart runs on the platform main thread on iOS and Android (default since 3.29, mandatory now); the raster thread is separate (Guide 4).
- Every scheduled frame sends a new Scene on stable 3.47.5, even if nothing repainted (Guide 2).
- The raster thread replays the whole frame; a BackdropFilter blur adds a pass break and 3 blur passes on the GPU (Guide 5, 6.2).
- The DevTools raster bar is raster-thread CPU time, not GPU time (Guide 9.1).
- Pipelining: the UI thread prepares frame N+1 while frame N rasterizes (pipeline depth 2 on Metal, Guide 4).
- Example values follow docs/render-stack-visualization.md; [verify]/[estimate] items are not yet checked on a device.''',
);

final uiHalfSlide = RenderStackSlide(
  route: '/pipeline-ui',
  title: 'Pipeline, UI half',
  section: '2a',
  script: uiHalfScript,
  speakerNotes:
      '''
$timSlideNotesHeader
Key message: painting records, layers group, and every scheduled frame sends a new Scene, even if nothing repainted (stable).
- paint() records a Picture (a DisplayList), a tape of draw commands. Nothing is drawn yet (Guide 3.1).
- Layers are containers for tapes and effects. Repaint boundaries keep their layer across frames; a BackdropFilter always gets a BackdropFilterLayer (Guide 3.2).
- markNeedsPaint walks up to the nearest repaint boundary; that boundary re-records its subtree (Guide 3.3).
- compositeFrame describes the layer tree to the engine as a new Scene, once per frame per view. Clean subtrees are addRetained. Cheap (Guide 3.4).
- "Retained" saves UI-thread work only; the GPU still draws that subtree.
- On the stack: tiers 3 (paint calls, tapes 1-4) and 4 (layer tree) expand; BackdropFilterLayer and the caret's OffsetLayer are emphasized.''',
);

final rasterHalfSlide = RenderStackSlide(
  route: '/pipeline-raster',
  title: 'Pipeline, raster half',
  section: '2b',
  script: rasterHalfScript,
  speakerNotes:
      '''
$jesperSlideNotesHeader
Key message: the raster thread flattens the tree into one DisplayList and replays all of it every frame. Draw calls are cheap, passes are costly. A BackdropFilter blur breaks the pass.
- One DisplayList per view per frame (per slice with platform views). No raster cache under Impeller (Guide 5).
- Partial repaint is off on mobile Impeller: never on Android, forced off on iOS by the external view embedder. Scope: "mobile Impeller, no platform views".
- saveLayer (ShaderMask, ColorFiltered, non-peephole Opacity): +1 offscreen pass, pasted back as "Subpass" (Guide 6.2 B).
- BackdropFilter blur: ends the parent pass, 3 blur passes (downsample, vertical, horizontal), restarts the pass with a full-screen "MSAA backdrop" redraw and replays clips. About 4-5 extra passes; count them in a capture (Guide 6.2 C).
- BackdropGroup / BackdropFilter.grouped shares one capture (and one blur if equal) (Guide 6.2).
- On the stack: the 2-slot handoff tray, tier 6 as one DisplayList, tier 7 as passes P1-P6; the bold CPU/GPU border runs through tier 7 at command-buffer commit (spec section 3).''',
);

final ahaSlide = RenderStackSlide(
  route: '/paint-vs-composite',
  title: 'Paint vs composite',
  section: '3',
  script: ahaScript,
  speakerNotes:
      '''
$timSlideNotesHeader
Key message: answer to the vote: C makes the frames, A makes each one expensive. A running Ticker means a full frame every vsync, whether or not anything repaints. GPU work = how often you draw x how hard each frame is.
- The focused iOS field's caret runs on an AnimationController. While its Ticker runs, it requests a frame every vsync: 120 a second at ProMotion (measured ~119 Scenes/s in the demo's widget test; one vsync per 1.017 s blink cycle has no frame scheduled).
- Every one of those frames builds a new Scene, and the raster thread and GPU re-render the whole screen with the blur: pass break + 3 blur passes (stable 3.47.5).
- Repaints are the small part: the caret's pixels change on ~8 frames per second (8 per blink cycle, measured). The other ~111 frames per second repaint nothing and still cost the full raster + GPU work.
- Each frame fits the budget, so no jank; the GPU just never idles. Heat builds, then throttling causes jank.
- Myth-buster: RepaintBoundary and const save UI-thread paint work, not frames, and not GPU work under Impeller.
- "A frame requested is not a frame rendered": flutter/flutter#192128 is a framework-side skip: a gate in RendererBinding.drawFrame that only composites when something repainted (needsCompositeFrame). On no-repaint frames no Scene is built, so nothing reaches the engine: no raster, no GPU, no FrameTiming. Measured on master: the caret drops from ~119 to ~7.9 Scenes/s. The Ticker still wakes the UI thread every vsync, and spinners (which really repaint) are not helped. Merged to master 2026-09-24, after the 3.49 beta cut: expected in 3.50 stable (estimate). Name it as coming until it ships.
- It's a defaults problem, not "your code is wrong".
- On the stack: loop T (Ticker frame) is the bold arc from the vsync, dim through tiers 1-4 (nothing dirty) and hot from the Scene up, with the counter "≈119 frames/s, ≈111 repaint nothing". The repaint loop C (≈8/s) is a thin side branch. Pulses run slowed x10.
''',
);

final profilingSlide = RenderStackSlide(
  route: '/profiling',
  title: 'Profiling',
  section: '5',
  script: profilingScript,
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

final hookSlide = RenderStackSlide(
  route: '/hook',
  title: 'Hook',
  section: '1',
  script: hookScript,
  speakerNotes:
      '''
$jesperSlideNotesHeader
Key message: a search sheet over the app drove the GPU to its limit and never let it rest. Pose it as a vote and leave it open.
- Vote: A) the blur, B) the list underneath, C) the blinking cursor, D) the keyboard.
- The sheet is a frosted BackdropFilter blur over a busy page, with a focused field.
- Show one real measurement with a footer: device + SoC, OS, Flutter version, --profile, 60/120 Hz, thermal state, duration, runs, metric source (Guide 9.2). No bare "GPU %".
- On the stack: the stack dims and the demo comes forward on a phone (real BackdropFilter, fading caret) with the vote.
- Answer comes in section 3: C makes the frames, A makes each one expensive.
- Get ClickUp's sign-off and facts (Flutter version, sheet widget, cursorOpacityAnimates, platform views?) before telling it (Guide 14).''',
);

final blurCostSlide = RenderStackSlide(
  route: '/blur-cost',
  title: 'Why blur costs',
  section: '4',
  script: blurCostScript,
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
- One line on liquid glass: the Flutter team is officially building it; any liquid-glass look is built on the same backdrop reads, so all of this applies, multiplied.''',
);
