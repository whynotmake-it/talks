# Feasibility: estimating Impeller GPU work from a widget test

**Status: prototype complete.** The idea works as an *estimate*: from a plain
`flutter test` we capture the layer tree and every recorded canvas op, rebuild a
DisplayList-like op stream, and replay it through a Dart port of Impeller's
`Canvas`/`DlDispatcher` decision logic. The output is an ordered pass timeline
(render passes, sizes, reasons, draw counts) plus a rough memory-traffic
estimate — per capability profile, without a device.

> **This is an estimate, not a contract.** The model mirrors Impeller
> implementation details pinned to engine **Flutter 3.47.1** (this checkout; the
> brief targeted commit `d3b14c87690` / 3.47.0 — the delta is documented risk).
> Validate against real captures before trusting any number.

## What was built

`packages/impeller_model`:

- `capture/` — `FrameRecorderBinding` (subclasses
  `AutomatedTestWidgetsFlutterBinding`) overrides `RendererBinding.createCanvas`
  and wraps every picture canvas in a recording proxy; `LayerWalker` walks
  `RenderView.debugLayer`; `captureFrame(tester)` forces a full repaint
  (`markNeedsPaint` on every render object) then joins layers ↔ recorded ops.
- `model/` — a Dart port of `Canvas::SaveLayer`/`Restore`/`FlipBackdrop`,
  the opacity peephole, `BackdropGroup` texture caching, advanced-blend
  handling, and Gaussian-blur pass generation, driven by `CapabilityProfile`s
  (`metal-apple4`, `metal-simulator`, `vulkan-fbf`, `vulkan-adreno<=630`).
- Output: `FrameReport` → JSON + a simple static HTML bar timeline.
- `test/cases_test.dart` — all ten brief cases; `test/frames_test.dart` —
  frame-request counting spike.

## How capture works (with evidence)

- **Canvas ops.** `ui.Picture` is opaque (`lib/ui/painting.dart` —
  `toImage`/`dispose`/`approximateBytesUsed` only). The documented hook is
  `RendererBinding.createCanvas` (`packages/flutter/lib/src/rendering/
  binding.dart:397`); `PaintingContext._startRecording` calls it per picture
  (`rendering/object.dart:362`). Our proxy records every `save`, `saveLayer`,
  `clip*`, `draw*`, `saveLayer`'s `Paint` (alpha, blendMode, imageFilter,
  colorFilter, invertColors, maskBlur) — everything the model needs except
  text/path internals (not needed for pass decisions).
- **Layer tree.** `RenderObject.debugLayer` (`rendering/object.dart:3184`),
  `ContainerLayer.firstChild`/`nextSibling` (`rendering/layer.dart`). The walk
  reads `BackdropFilterLayer.filter|blendMode|backdropKey`
  (`layer.dart:2340-2375`), `OpacityLayer.alpha`, clip layers' shapes,
  `TransformLayer.transform`, `ImageFilterLayer`, `ColorFilterLayer`,
  `ShaderMaskLayer`, `PictureLayer`, plus `debugCreator` for attribution.
- **Join.** `createCanvas` fires in *paint* order, which does NOT always
  match layer-tree DFS order — repaint boundaries repaint in dirty-node
  order (before the root view's own picture). The synthesizer therefore
  matches pictures to `PictureLayer`s by CONTENT: each picture's recorded
  op-bounds union must fit inside the layer's `canvasBounds`
  (layer.dart:834), tightest fit wins, with positional fallback. The
  `opacity_overlap_pictures` case caught the original positional join
  silently mis-assigning the root picture.

### Capture pitfalls discovered (documented, important)

1. **Multiple drawFrames per `pumpWidget`.** `scheduleWarmUpFrame` runs a full
   frame at attach, and `testWidgets`/`runApp` paths add more. Layer trees seen
   after *different* frames differ. *Fix:* `captureFrame` marks every render
   object dirty and pumps a fresh frame, then walks — the ops and layers are
   guaranteed to correspond. This also makes capture deterministic.
2. **Retained pictures are never re-recorded.** `createCanvas` only fires for
   pictures that repaint. Without the forced repaint, partial frames silently
   lose ops (the registry clears per `drawFrame`).
3. **`debugOnProfilePaint` lies about painting.** It fires on `paintChild`
   *visits* (`rendering/object.dart:251`) even when the child's paint early-outs
   (`_needsLayout`) or draws nothing. We burned an hour on a zero-size
   `ColoredBox` that legitimately produced no ops.
4. **`BackdropFilter.enabled` exists now** (3.47 API change):
   `RenderBackdropFilter.paint` skips layer creation entirely when disabled
   (`rendering/proxy_box.dart:1329`). `BackdropFilter.grouped` is what picks up
   `BackdropGroup.of(context).backdropKey` (`widgets/basic.dart:659-672`) —
   plain `BackdropFilter` inside a group keeps `backdropKey: null`.
5. **`RenderBackdropFilter.filterConfig`/`ImageFilterConfig`** is the new
   abstraction (`basic.dart:698-712`); the layer still exposes
   `ui.ImageFilter` (`layer.dart:2340`), and `ImageFilter.toString()` exposes σ
   — we parse blur σ from it (fragile, see risks).
6. **Zero-size render objects paint nothing.** A `ColoredBox` under loose
   constraints produces zero ops AND zero pictures — not a capture bug
   (verified via `debugOnProfilePaint` vs `context.canvas` access).

## Frame-request counting (spike)

`FrameRecorderBinding` overrides `scheduleFrame`, `scheduleForcedFrame` and
`scheduleFrameCallback`, counting requests with requester attribution from
stack traces, plus `framesDrawn` (drawFrame count) and `framesPainted`
(drawFrames that recorded ≥1 picture).

**Important caveat:** in a widget test `tester.pump()` is the vsync — every
pump schedules and draws a frame, so `framesDrawn` trivially equals pump
count. `framesPainted` is the meaningful signal (a drawFrame with zero
recordings means nothing repainted). Attribution lands mostly on
`flutter_test`'s own pump path; a real app's per-ticker requests show up via
`tickerRequests` (the `scheduleFrameCallback` → `Ticker.scheduleTick` path,
ticker.dart:299). This is a useful spike but not yet the talk's "119 frames/s
requested vs 8/s repaint" measurement — that needs counting ticker
registrations over idle time without pumping (the test harness's pump loop
dominates the signal).

## What the model reproduces (validation cases)

Surface: `2400×1800` physical @ DPR 3 (800×600 logical test view).

| Case | Model output (metal-apple4) | Verdict |
|---|---|---|
| Plain screen | 1 onscreen pass, ~0 extra traffic | ✓ |
| BackdropFilter σ=10 | root offscreen → flip→onscreen + 3 blur passes 300×225 + subpass = **6 passes, 1 flip, ~174 MB** | ✓ matches expected shape |
| Two sibling blurs | **11 passes, 2 flips, ~349 MB** | ✓ |
| Same in `BackdropGroup` (`BackdropFilter.grouped`) | **5 passes, 1 flip, ~88 MB** — shared snapshot, filter applied once | ✓ group semantics hold |
| Two blurs inside 400×300 clip | **11 passes, ~217 MB** — clip-sized subpasses 1200×900, blurs 150×113 | ✓ |
| Identity-matrix backdrop barrier inside tight clip | inner blurs flip the *clip-sized* subpass — **14 passes, ~282 MB** (barrier costs a flip; inner flips cheaper) | ✓ mechanism reproduces; see note |
| `BlendMode.saturation` full screen | fbf: 1 pass, ~0. no-fbf (adreno≤630/sim): 4 passes + flip | ✓ |
| Full-screen blur + grayscale matrix | **6 passes, ~174 MB** vs 1-pass saturation | ✓ ~2 "real" passes + blur subpasses |
| Opacity, single child | peephole → 1 pass | ✓ |
| Opacity, overlapping children | overlap detected → **2 passes** (subpass + root) | ✓ (needed `overlapDetected` propagation fix) |
| CupertinoNavBar + TabBar (default colors) | **1 blur, ~94 MB** — nav bar's `enabled=false` | ⚠ see below |
| Opaque Cupertino bar colors | 1 pass, no blur | ✓ |

### Discrepancies vs the brief's expectations

- **Cupertino bars: 1 blur, not 2.** On 3.47.1 the nav bar's backdrop is
  *disabled at rest*: `effectiveBackgroundColor` lerps from the parent
  scaffold's *opaque* background toward the translucent bar color by
  `_scrollAnimationValue` (`cupertino/nav_bar.dart:753-758`), and
  `enabled: backgroundColor.alpha != 0xFF` (`nav_bar.dart:253-254`). At rest it
  resolves opaque → no `BackdropFilterLayer`. The blur only exists while
  scrolled-under. The model faithfully reports this; the brief's "two blurs"
  holds only mid-scroll.
- **Blur texture size.** σ=10 → `ScaleSigma` → σ≈27 after the ×3 DPR basis
  (`effect_transform.Basis()` multiplies σ by the entity scale —
  `gaussian_blur_filter_contents.cc:106-110`) → `CalculateScale` = 1/8
  (`gaussian_blur_filter_contents.cc:751-776`) → 300×225. Model matches.
- **`flip→onscreen` clears readback** — fixed the model to zero
  `_requiresReadback` on the onscreen flip (engine: `canvas.cc:2475`).
- **Every backdrop counts toward `backdrop_count_`** — even ungrouped
  (unkeyed) ones (`dl_dispatcher.cc:1002`), which gates the last-backdrop
  onscreen flip (`canvas.cc:1822-1831`). Model mirrors it.
- **Blur pass sizing is *clip coverage***, not filter widget bounds — backdrop
  saveLayers flood input coverage to the coverage limit (clip), then the blur
  downsamples *that*. Tab-bar case: clip 800×50 → blur textures 300×19.
- **The barrier trick's payoff is situational in the model.** With two small
  blurs, the identity-matrix barrier *costs* a flip + clip-sized subpass (~42 MB)
  but only saves the size-difference on inner flips — net ≈ a wash vs. plain
  clipping (~108 vs ~83 MB, i.e. *worse* here). Its real value shows when inner
  flips would otherwise hit a big root texture many times, or when combined
  with `BackdropGroup`. Worth re-checking against a GPU capture.
- **Memory traffic convention:** each offscreen pass break costs
  `width×height×4 ×2` (store + reload); the pass that finally writes the
  onscreen surface is free (talk's 1179×2556×4 ≈ 12 MB rule applied at our
  2400×1800 test surface ≈ 33 MB per break). This is a rough upper bound —
  it ignores partial-renderable coverage and resolve targets.

## Where the model can be wrong

- **Ops inside retained/reused pictures** — mitigated by forced full repaint;
  partial-repaint frames lose op-level detail (`FrameCapture.pictureMismatch`
  flags it).
- **`Picture`-internal data** is unknowable: text content, path detail — only
  op-level structure survives. Enough for pass decisions, not for coverage
  precision: bounds come from op arguments and estimates. Within a picture
  the model now mirrors `dl_builder` scoping: a nested `canvas.saveLayer`
  contributes only union bounds to the parent accumulation
  (`TransferLayerBounds`, dl_builder.cc:761), and its `can_distribute_opacity`
  is computed at the matching restore from real content bounds.
- **Opacity granularity** follows `dl_dispatcher.cc:803-810`: outstanding
  opacity is consumed per `DrawDisplayList` — one `saveLayer(alpha)` per
  picture child — and multiplies into nested saveLayer paints rather than
  nesting them. A `drawDisplayList` op propagates
  `can_apply_group_opacity` (dl_builder.cc:1819); a nested saveLayer does not
  propagate internal overlap.
- **σ parsing from `ImageFilter.toString()`** — stringly-typed, version-fragile.
- **Partial repaint** (`kImpellerRepaintRatio` 0.7, `flow/compositor_context.cc:210`)
  not modeled — we always model a full repaint.
- **MSAA resolves, mip levels, partial-blits, texture discards** — not modeled;
  traffic is the store+load-per-break heuristic only.
- **Raster cache, platform views, shadows, glyph atlas** — partially modeled or
  absent.
- **`ImageFilter.matrix`/convolve/shader filters** — modeled generically as a
  filter pass; exact pass shapes not ported.
- **Ordered-vs-postprocess differences in `BackdropGroup` paths** — our model
  skips the member's own subpass (engine draws the filtered snapshot entity
  into the parent pass, `canvas.cc:1858-1887`), which matches. Filter equality
  uses `ui.ImageFilter.operator==` (real content comparison — sigma, matrix
  data, inner/outer; painting.dart:4514), falling back to toString only when
  the source object is unavailable.
- **`ui.Canvas` internals**: `Vertices` bounds are unknowable → treated
  unbounded; `drawAtlas`/`drawVertices` are forced overlap + incompatible
  (matching dl_builder.cc:1547/1736/1819-ish behavior); `drawPicture` across
  recorders isn't captured → unbounded + incompatible (conservative).
- **Text/glyph internals are not introspected** — `drawParagraph` is
  recorded as opacity-incompatible (matching dl_builder.cc:1855's
  conservative glyph-overlap flag), so `Opacity`-over-text correctly
  produces a subpass, but glyph bounds are unknown (paragraph bounds used).
- **Draw-level `Paint.maskFilter` is not modeled** — a mask blur on a draw
  op should spawn the same downsample/Y/X filter passes that a
  `Paint.imageFilter` now does; only `Paint.imageFilter` and saveLayer
  filters are handled.
- **`debugOnProfilePaint` / `debugSymmetricPaintCount` repaint hooks from
  the brief are not implemented** — `framesPainted` (frames with ≥1 recorded
  picture) is the partial substitute; it counts *canvas* activity but not
  every visited paint. Fine-grained repaint attribution needs the engine
  hooks listed above.
- **`FollowerLayer` link offsets** — treated as a transparent scope (bounds
  propagate) but the link offset itself is ignored, so a follower's bounds
  sit at the leader's position, not the follower's.
- **Blend scoping is now correct in both directions**: blends *inside* a
  saveLayer composite against the subpass texture and do NOT reach
  `max_root_blend_mode` (dl_dispatcher.cc:942-951); the saveLayer op's own
  composite blend DOES (it's a parent-scope op). The
  `saveLayer_blend`/`saveLayer_blend_inside` tests pin both cases.
- **Advanced-blend-per-draw breaks** — a draw inside a saveLayer with advanced
  blend breaks *that* pass; blended restores break on restore
  (`canvas.cc:2029`, `2366`). Modeled but only lightly exercised.

## Maintenance risk

High but bounded. Everything hinges on framework internals
(`debugLayer`, `createCanvas`, layer class names, `ImageFilter.toString`,
`BackdropFilter.enabled`/`grouped`) and engine internals (`Canvas`,
`dl_dispatcher`, blur passes) that are *not* stable API — the 3.47 cycle alone
moved `backdropKey`/`enabled`/`filterConfig`. The model is pinned to
engine-`3.47.1`; every Flutter release needs a re-verification pass (the
`file:line` citations below are the audit checklist). The value proposition
("did my change add a pass?") survives mild drift; absolute numbers don't.

## Validation performed

- `flutter test` (Skia tester): all 26 tests pass; model output matches
  expectations per case above.
- `flutter test --enable-impeller` (SwiftShader/Vulkan): all 26 tests pass —
  the recording proxy is transparent under real rasterization, and the
  `vulkan-fbf` profile output is the closest to that backend's real behavior.
- **Not validated against real pass-level data.** `flutter test` attaches
  no VM service, so timeline counters (saveLayer count, raster ms) aren't
  reachable in-process — the comparison the brief asks for would need a
  `flutter run --enable-impeller` harness. `--enable-impeller` exposes
  almost no pass-level timeline events (see brief) — `Canvas::saveLayer` counts
  calls not passes. Xcode GPU captures (count `EntityPass Render Pass` /
  `Gaussian Blur Filter` encoders) would validate pass counts exactly;
  **Jesper's iPhone capture is still the missing piece.**

## Recommendation

**Ship as an experiment, pursue the engine route for precision.**

The pure-Dart model already produces correct *structural* answers on the brief's
own test matrix — pass counts, flips, blur subpass sizes, group-vs-ungrouped
differences, the fbf-vs-Adreno blend split, the opaque-bar effect. That's the
"change the widget tree, see 4 passes → 1" inner loop the brief wants.

For numbers you'd publish, pure Dart tops out: no `Picture` readback, no
damage rects, no MSAA, and every cited line is a moving target. The engine-side
path (option 4, a C++ harness replaying a serialized op stream through
`CanvasDlDispatcher` with `MockCapabilities`) is where exact answers live.

## Engine hooks that would make this robust

1. **Pass-level trace events.** `FlipBackdrop`, `SaveLayer`-vs-peephole,
   `InlinePassContext::GetRenderPass`/`EndPass`, `BlitToOnscreen` — ~5
   `TRACE_EVENT`s. One build flags them on; `--enable-vmservice` exposes them
   to Dart. This makes the *real* pass structure observable in tests instead of
   inferred. Cost: minimal, they're no-ops when tracing is off.
2. **A debug DisplayList readback API.** `DisplayListStreamDispatcher`
   (`testing/display_list_testing.h`) already serializes ops — exposing it
   (or `ui.Picture.debugRecord`) to tests removes the content-matching
   join's fragility (ambiguous when two pictures share identical bounds)
   and gives true op semantics including text/para bounds.
3. **`RendererBinding.createCanvas` is a good start; a stable
   `RenderView.debugLayer` + per-frame hook** (e.g. `debugOnLayerTreeComposited`)
   would remove the "capture the right frame" dance.
4. **Backdrop identity visible to tests.** `backdropKey`'s `_key` int is what
   the engine uses for group caching (`backdrop_filter_layer.cc`) — exposing
   the resolved id on `BackdropFilterLayer` removes the
   `BackdropFilter.grouped`-vs-`backdropGroupKey` ambiguity we hit.
5. **Deterministic "capabilities probe"** — a debug setter to force
   framebuffer-fetch off / simulate Adreno-630 workarounds in `flutter_tester`,
   so `--enable-impeller` tests can exercise the no-FBF path on CI.

## Key engine citations (3.47.1)

- `impeller/display_list/canvas.cc:1710` `Canvas::SaveLayer`; `:1722-1732`
  peephole; `:1798-1858` backdrop/flip+cache; `:1900-1937` subpass +
  backdrop-entity-in-subpass; `:2029` saveLayer-restore advanced blend;
  `:2353-2370` per-draw advanced blend; `:2415` `FlipBackdrop`; `:2475`
  `requires_readback_ = false` on onscreen; `:2531-2538` `SupportsBlitToOnscreen`
  (Metal-only texture blit); `:2611-2618` final blit vs in-place.
- `impeller/display_list/dl_dispatcher.cc:942-951` root offscreen decision
  (`has_root_backdrop_filter || RequiresReadbackForBlends`); `:996-1013`
  `backdrop_count_` counts *all* backdrops; `:1225`/`:1286`/`:1322` root flags
  forwarded.
- `impeller/entity/entity.h:28-29` `kLastPipelineBlendMode=kModulate`,
  `kLastAdvancedBlendMode=kLuminosity`; `entity.cc:128` `IsBlendModeDestructive`.
- `display_list/dl_builder.h:565-572` `is_group_opacity_compatible` =
  no-incompatible-ops ∧ no-overlap; `dl_builder.cc:723` the gate.
- `impeller/entity/contents/filters/gaussian_blur_filter_contents.cc:95-125`
  σ×entity-transform scaling; `:283-300` downsample args; `:751-776`
  `CalculateScale` (min 1/16, pow2, kernel-size extension);
  `:985-1010` `CalculateBlurRadius`/`ScaleSigma` quadratic.
- `impeller/entity/save_layer_utils.cc` `ComputeSaveLayerCoverage` (backdrop
  floods input coverage to limit); `clip_contents.cc:45` difference-clip
  doesn't shrink.
- `flow/layers/opacity_layer.cc:80` `applyOpacity`; `backdrop_filter_layer.cc`
  `applyBackdropFilter` (bounds = children ∪ cull rect).
- `flow/compositor_context.cc:210` `kImpellerRepaintRatio=0.7`.
- `impeller/renderer/backend/metal/context_mtl.mm:24` FBF on Apple2+;
  `vulkan/workarounds_vk.cc:17` Adreno≤630/PowerVR off;
  `gles/capabilities_gles.cc:155` `GL_EXT_shader_framebuffer_fetch`.
- `scheduler/binding.dart:946-958` `scheduleFrame` + `debugPrintScheduleFrameStacks`;
  `ticker.dart:291-299` `scheduleTick` → `scheduleFrameCallback`.

## Reproduce

```bash
cd packages/impeller_model
/Users/tim/fvm/versions/3.47.1/bin/flutter pub get
/Users/tim/fvm/versions/3.47.1/bin/flutter test            # writes example/output/*.json|html
/Users/tim/fvm/versions/3.47.1/bin/flutter test --enable-impeller
```

**Packaging notes:** the package is intentionally *not* in the root
`workspace:` list — it resolved cleanly standalone, and keeping it out avoids
coupling it to the repo's pinned dependency overrides; `melos` therefore
won't run it. `flutter_test` is a regular dependency (not dev) because
`lib/src/capture/binding.dart` is public API subclassing
`AutomatedTestWidgetsFlutterBinding` — the same pattern `integration_test`
uses. Linting uses `lintervention` like sibling packages (style-noise rules
silenced in `analysis_options.yaml`).
