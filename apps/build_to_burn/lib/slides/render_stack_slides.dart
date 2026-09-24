import 'package:build_to_burn/slides/render_stack_slide.dart';
import 'package:build_to_burn/visualizations/render_stack/render_stack_content.dart';
import 'package:wnma_talk/slide_number.dart';

// The slides that show the render stack, one per build-up step of
// docs/render-stack-visualization.md that has shipped (1, 3, 4, 5, 8).

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
Key message: answer to the vote: C makes the frames, A makes each one expensive. GPU work = how often you draw x how hard each frame is.
- iOS: TextField defaults cursorOpacityAnimates to true; the caret is an AnimationController whose ticker asks for a frame every vsync (60 or 120/s) while focused. Android default: a 500 ms timer, 2 frames/s (Guide 7.2).
- The caret sits in its own repaint boundary: a tick re-records one rect, and nothing during the hold phases.
- On stable, every tick still sends a new Scene, and the raster thread re-renders the whole screen with the blur: pass break + 3 blur passes, up to 120 times a second.
- Each frame fits the budget, so no jank; the GPU just never idles. Heat builds, then throttling causes jank.
- Myth-buster: RepaintBoundary and const save UI-thread work, not GPU work, under Impeller.
- "A frame requested is not a frame rendered": flutter/flutter#192128 (master) skips ticks where nothing repainted. Helps the caret during holds, not spinners. Name it as coming unless it has reached stable.
- It's a defaults problem, not "your code is wrong".
- On the stack: arcs A (Rebuild), C (Repaint), E (Scene only). Caret tick lighting: tiers 1-2 off, 3-5 dim, 6-9 hot (spec section 5). Arcs pulse at the real rate slowed x10.''',
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
