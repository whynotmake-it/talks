# Handoff: explore a static "frame cost" model for Flutter (experimental)

This is an **exploration brief**, not a build spec. Your job is to find out whether this idea can work, build the smallest prototype that proves or disproves it, and write a clear feasibility report. Read this whole document before writing code.

## The idea

A Flutter package that, from a plain **widget test** (`flutter test`, no device) or a debug run, captures what one frame produces:

- the render objects
- the layer tree
- the draw operations

It then **estimates how Impeller turns that frame into GPU work**: render passes, pass breaks and why they happen, offscreen layers and their sizes, blur passes, and rough memory traffic. It shows the result as a timeline or visualization.

Optionally it also counts **how many frames get requested** over a stretch of simulated idle time, and **who requested them** (which Ticker or animation). That gives both factors of the talk's formula, **GPU work = frames per second × cost per frame**, without a device.

**Why it matters:** on-device benchmarks are slow and noisy. Thermal state, battery level, power saving and background load all move the numbers. A deterministic, device-free estimate would give a coding agent a fast inner loop: change the widget tree, re-run the test, and see "this frame went from 4 passes to 1". The on-device harness (see `01_gpu_benchmark_harness.md`) stays the source of truth. This tool is the quick estimate you check against it.

**Known risk:** this mirrors Impeller *implementation details* that are not a public contract, and they can change in any release. The model must be pinned to an engine version, labeled as an estimate, and validated against real frame captures.

## Ground rules

- **Read the manual first.** Read the official docs and the actual source for every API and engine path you rely on. Don't guess, and don't trial-and-error.
- **Source:** local Flutter SDK 3.47 at `/Users/jesper/Development/SDKs/flutter` (commit `d3b14c87690`). The framework is in `packages/flutter`, `packages/flutter_test`, `packages/flutter_tools`. The engine is in `engine/src/flutter` (`impeller/`, `display_list/`, `flow/`, `lib/ui/`).
- **Cite `file:line`** for every engine behavior the model copies.
- **Ask the humans** (Jesper, Tim) before building the engine locally. It needs a full gclient sync, which costs a lot of time and disk space.

## What earlier research already found

Paths are relative to the SDK. `pkg/` = `packages/flutter/lib/src/`, `eng/` = `engine/src/flutter/`. Re-verify before relying on any of it.

### Capturing the frame from Dart: works

- **Layer tree.** After a pump, walk `RenderView.debugLayer`. `RenderObject.debugLayer` is at `pkg/rendering/object.dart:3184`. The traversal API is `ContainerLayer.firstChild`/`lastChild` and `Layer.nextSibling` (`pkg/rendering/layer.dart`). Readable properties include:
  - `BackdropFilterLayer.filter` / `blendMode` / `backdropKey` (`backdropKey` becomes the engine's `backdropId`, for `BackdropGroup`)
  - `OpacityLayer.alpha`
  - clip layers' shapes
  - `ColorFilterLayer`, `ImageFilterLayer`, `ShaderMaskLayer`, `TransformLayer`, `PictureLayer.picture`
- **Draw ops.** `ui.Picture` cannot be read back. It only offers `toImage`, `dispose` and `approximateBytesUsed` (`eng/lib/ui/painting.dart:8436`). But `RendererBinding.createCanvas(recorder)` (`pkg/rendering/binding.dart:397`) is a documented test hook: "enables test bindings to instrument the rendering layer". `PaintingContext._startRecording` calls it for every PictureLayer (`object.dart:359`). A proxy `Canvas` that records each call and passes it through gives you every op, including `saveLayer`, clips, blend modes, `drawParagraph` (text content stays opaque) and `drawPicture`. Install it by subclassing `AutomatedTestWidgetsFlutterBinding`. Optionally also wrap `RendererBinding.createSceneBuilder()` (`binding.dart:380`) to see the push calls the engine receives.
- **Mapping back to widgets.** `Layer.debugCreator` is set only on repaint-boundary layers. Build the map from the render tree instead: walk it, read `debugLayer`, and follow `RenderObject.debugCreator` to the Element.
- **Caveat: compositing.** Clip, transform and opacity *layers* only exist when `needsCompositing` is true (`object.dart:584`). Otherwise they appear as ops inside a picture. You need both sources.
- **Don't build on flutter_test's `paints` matcher** (`TestRecordingPaintingContext`). It ignores `pushLayer`, drops the opacity alpha, and loses children under `pushColorFilter`.
- **Repaint information per frame.** Use `debugOnProfilePaint` (`pkg/rendering/debug.dart:233`) and `debugEnhancePaintTimelineArguments`, which add dirty lists to the PAINT timeline event. There are also `RenderRepaintBoundary.debugSymmetricPaintCount`/`debugAsymmetricPaintCount`, and `FlutterTimeline.debugCollect()` for in-process timings.

### Running real Impeller in a test: works, but you can't see passes

- `flutter test --enable-impeller` (`flutter_tools/lib/src/commands/test.dart:80`) renders through Impeller on **Vulkan via SwiftShader** inside `flutter_tester` (`eng/shell/testing/tester_main.cc:50`). Metal only works by calling `flutter_tester` directly with `--impeller-backend=metal`.
- SwiftShader behaves like a device **with** framebuffer fetch, and MSAA is on.
- The engine's trace events reach the Dart timeline (`flutter test --enable-vmservice`, then `getVMTimeline`). But Impeller emits almost no pass-level events:
  - `Canvas::saveLayer` fires on entry, so it counts calls, not passes.
  - `PipelineVK::Create` fires only the first time a pipeline is used.
  - Raster-side timings are available.
- **Render pass names are debug labels, not trace events.** `EntityPass Render Pass` (`eng/impeller/entity/inline_pass_context.cc:148`) and `Gaussian Blur Filter` only show up in GPU capture tools.
- **Patched local engine:** adding about five `TRACE_EVENT`s (in `FlipBackdrop`, in `SaveLayer` after the peephole check, in `InlinePassContext::GetRenderPass`/`EndPass`, and in `BlitToOnscreen`), then running `flutter test --local-engine`, would expose exact pass structure to Dart. This needs an engine build. There is no `engine/src/out` on this machine yet.

### Impeller decision logic a cost model must copy

All of this is in `eng/impeller/display_list/canvas.cc` and `dl_dispatcher.cc`.

- **Flattening into one DisplayList.** The flow layer tree becomes one DisplayList per frame (`eng/flow/compositor_context.cc:146`).
  - OpacityLayer becomes a saveLayer, unless its children can take the opacity (`flow/layers/opacity_layer.cc:51`).
  - ShaderMask, ColorFilter, ImageFilter and BackdropFilter layers always become a saveLayer.
  - A clip with `antiAliasWithSaveLayer` becomes a saveLayer.
- **Offscreen root.** The frame is drawn offscreen from the start when there is a root backdrop filter, or an advanced blend on a device without framebuffer fetch (`dl_dispatcher.cc:933`). At the end it is copied onscreen: a blit on Metal, an extra pass elsewhere (`canvas.cc:2531`, `:2607`).
- **saveLayer** (`canvas.cc:1710`).
  - It is skipped when the coverage limit is empty (`GetLocalCoverageLimit`, `:1673`). The limit is the parent pass texture ∩ the clip coverage. The clip coverage is the **bounding box** of any intersect clip (`eng/impeller/entity/contents/clip_contents.cc:45`). A difference clip doesn't shrink it.
  - The **opacity peephole** (`:1728`) turns the saveLayer into a plain save. It requires `can_distribute_opacity` from the DisplayList builder, no backdrop, `Paint::CanApplyOpacityPeephole`, and bounds that don't clip contents.
  - Otherwise, a new offscreen pass, sized by `ComputeSaveLayerCoverage` (`eng/impeller/entity/save_layer_utils.cc`). A backdrop filter floods the coverage to the clip.
- **Backdrop filter.** `FlipBackdrop` (`canvas.cc`) ends the **current** pass (whichever is on top of the stack), restarts it, and redraws the stored texture as the "MSAA backdrop", plus clips.
  - `BackdropGroup` (same `backdrop_id`, used more than once) caches the first flip's texture, and runs the filter once if all filters are equal (`:1810–1885`).
  - The last backdrop can flip back onscreen when framebuffer fetch exists and only one pass is open (`:1828`).
- **Advanced blends** (above `kLastPipelineBlendMode` = `kModulate`, in `eng/impeller/entity/entity.h:28`). With framebuffer fetch: `ApplyFramebufferBlend`, in-pass. Without it: `FlipBackdrop` plus a blend filter, per draw (`:2353`) and per saveLayer restore (`:2016`).
- **Gaussian blur.** Downsample scale is `CalculateScale(sigma)` (`eng/impeller/entity/contents/filters/gaussian_blur_filter_contents.cc:751`): 1 if σ ≤ 4 (in physical pixels), otherwise the nearest power of two of 4/σ, but no lower than 1/16. The blur then runs a downsample pass, a Y pass and an X pass (`:464–620`).
- **Partial repaint.** Only when the damage width or height is ≤ 70% of the frame (`kImpellerRepaintRatio`, `eng/flow/compositor_context.cc:210`). Whether it's active depends on the platform; verify that per platform.
- **Capability profiles the model must take as input:**
  - **Framebuffer fetch:**
    - Metal: on for `MTLGPUFamilyApple2`+, off on the iOS Simulator (`eng/impeller/renderer/backend/metal/context_mtl.mm:24`).
    - Vulkan: on, except Adreno ≤ 630 and all PowerVR (`backend/vulkan/workarounds_vk.cc:17`).
    - GLES: only with `GL_EXT_shader_framebuffer_fetch` (`backend/gles/capabilities_gles.cc:155`).
  - **MSAA and resolve support** per backend.
- **Memory-traffic rule of thumb from the talk:** a pass break stores and reloads the **whole current target**, not the blurred region. An iPhone 15 Pro full-screen texture is 1179×2556×4 B ≈ 12 MB, so one backdrop blur costs about 24 MB of extra traffic per frame. That is an **estimate**. Label it so in the output.

### Engine-side options, if pure Dart isn't precise enough

- `DisplayListStreamDispatcher` (`eng/testing/display_list_testing.h:98`) dumps ops.
- `impeller/renderer/testing/mocks.h` has `MockCapabilities` (with a framebuffer fetch toggle) and a `MockCommandBuffer` whose `CreateRenderPass` calls can be counted.
- `canvas_unittests.cc` already branches on capabilities.
- A C++ gtest that rebuilds a serialized op stream and replays it through `CanvasDlDispatcher` would give **exact** pass counts for every capability profile. It needs an engine build.

## Approaches, ranked by feasibility (from the research)

1. **Pure Dart static model** (works today, approximate):
   - proxy canvas + layer walk
   - rebuild a DisplayList-like op stream
   - a Dart port of the saveLayer/restore/backdrop/blend decision logic, driven by a capability profile
   - repaint data from the debug hooks
   - output a pass timeline
2. **Coarse sanity check with real Impeller:** the same tests under `flutter test --enable-impeller --enable-vmservice`, comparing saveLayer counts and raster timings against the model. This only covers the SwiftShader/Vulkan-with-fetch profile.
3. **Patched local engine with pass trace events.** Exact for the backends you can run. Medium cost.
4. **Standalone C++ harness** with mock capabilities. Exact for every profile. Highest cost.
5. **libimpeller over FFI.** Weak: no `backdrop_id`, no pass introspection.

Start with 1. Use 2 as a cheap check. Only propose 3 or 4 in the report, with an effort estimate. Don't start them without asking.

## Spike plan

1. **Capture.** Write a test binding that records ops through `createCanvas`, walks the layer tree after `pump`, and maps layers to widgets. Dump a JSON "frame description".
2. **Model.** Implement the decision logic for the cases below. Output per frame:
   - an ordered list of passes: target, size, reason (root / saveLayer / backdrop flip / blur downsample, Y, X / advanced blend / onscreen blit), draw count
   - estimated bytes stored and loaded per pass break
3. **Frames (optional but valuable).** With fake time, pump through 1–2 s of "idle" and count frames scheduled vs. frames that actually painted. Attribute them to active Tickers / `AnimationController`s (`SchedulerBinding` transient callbacks, `debugPrintScheduleFrameStacks`). This should reproduce the talk's caret case: ~119 frames/s requested at 120 Hz, ~8/s repaint.
4. **Visualize.** A static HTML/SVG timeline of passes per frame. Keep it simple.
5. **Validate.** Compare the model's pass list against:
   - (a) the `--enable-impeller` timeline numbers
   - (b) a real Xcode GPU frame capture on an iPhone, which Jesper can provide. Count render command encoders labeled `EntityPass Render Pass` / `Gaussian Blur Filter`.

## Test cases with expected outcomes

These come from the talk's analysis of the 3.47 source. Confirm or refute each one, and write down where the model and reality differ.

- **Plain screen, no effects:** one onscreen pass.
- **One `BackdropFilter` blur, σ=10, at a 3× device pixel ratio:** offscreen root, one flip, downsample at 1/8 plus Y and X passes, restart with a backdrop redraw, onscreen at the end.
- **Two sibling backdrop blurs vs. the same two in a `BackdropGroup` vs. the "identity-matrix backdrop inside a tight clip" trick** (a BackdropFilter with an identity color matrix wrapping both blurs inside a ClipRect, so the inner flips only cost clip-sized passes): compare pass counts and bytes. Note that `BackdropGroup` makes every member read the *same* cached background, which changes the look for stacked glass.
- **Advanced blend (`BlendMode.saturation` full-screen rect)** with framebuffer fetch: no break. Without it (Adreno ≤ 630 profile): a flip.
- **Full-screen `BackdropFilter` with a grayscale `ColorFilter.matrix`:** expected about 2 passes on iPhone vs. 1 for the saturation rect. See `apps/build_to_burn/scratch_book/blend_vs_backdrop.dart` in the talk repo.
- **`Opacity` over a single non-overlapping child (peephole) vs. over overlapping children** (saveLayer).
- **Default `CupertinoNavigationBar` + `CupertinoTabBar`:** two backdrop blurs, because the default bar color `0xF0F9F9F9` is not opaque. With an opaque color: none.

## Deliverables

- `FEASIBILITY.md`, with:
  - what works, what doesn't, and why, with `file:line` evidence
  - accuracy against the validation cases
  - the maintenance risk across Flutter versions
  - a recommendation: ship as an experiment, pursue the engine route, or drop the idea
- A prototype package (it can be rough) plus example tests for the cases above, and sample output (JSON + HTML).
- A list of engine hooks that, if Flutter added them upstream, would make this robust. For example: pass-level trace events, or a debug API to read DisplayList ops. Each with a one-paragraph justification. This could become an issue or RFC proposal later.

## Report back

Report early if a blocker kills an approach. Include exact commands, versions and evidence for every claim.
