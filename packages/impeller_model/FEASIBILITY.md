# Feasibility: estimating Impeller GPU work from a widget test

**Status: usable for the talk and for budgets in tests.** From a plain
`flutter test`, `impeller_model` reconstructs the render passes Impeller
encodes for a frame, per device class, and the frames a screen requests while
idle. The pass structure was checked against real GPU traces of 14 scenes on
macOS Metal and on a Pixel 10 (Vulkan without framebuffer fetch): 14/14 match
on both, and a test fails when the model drifts from those traces. iOS devices were not traced (by decision; see
[Not validated](#not-validated)).

It stays an **estimate**: a port of one Flutter release (3.47.1), with
nominal bytes and no GPU time. It answers "does this change add or remove
passes, and on which devices" reliably; it does not answer "how many
milliseconds or milliwatts".

## How it works

1. **Capture.** `ImpellerModelBinding` (an
   `AutomatedTestWidgetsFlutterBinding`) overrides `createPictureRecorder` and
   `createCanvas`, wraps every picture canvas in a recording proxy and keeps
   the ops per `ui.Picture` in an `Expando`. Walking `RenderView.debugLayer`
   then joins each `PictureLayer` to its picture's ops exactly, including
   retained pictures from earlier frames, without forcing a repaint.
2. **Synthesis** (`engine/display_list.dart`). The layer tree becomes the
   DisplayList op stream the engine would build: `flow/layers/*` preroll and
   paint, `dl_builder` saveLayer bookkeeping (bounds, overlap, opacity
   compatibility, unbounded content).
3. **Replay** (`engine/canvas.dart`, `gaussian_blur.dart`). A port of
   Impeller's `Canvas` save/restore/backdrop flip and filter pass generation,
   parameterized by a `CapabilityProfile` (backend, framebuffer fetch, pixel
   format). Output: an ordered pass list with role, size, Impeller label,
   cause and the widget it is charged to.
4. **Report** (`api/`). Per device preset: passes, cost centers, traffic,
   compare-with-capture labels; JSON and a self-contained HTML report with an
   optional snaptest screenshot.

Every engine decision is quoted from the 3.47.1 source next to its port;
`tool/engine_refs.dart` verifies all 143 quotes and lists the ones an SDK
upgrade touches ([MAINTAINING.md](MAINTAINING.md)).

## Validation

### What is compared

The `validation/` app renders each scene continuously. A profile build on
macOS is traced with Instruments' Metal System Trace (`xctrace`); render
encoders are grouped per frame and counted by Impeller label. On the Pixel 10
a Vulkan layer logs the size and sample count of every render pass per
present, since Vulkan carries no Impeller labels outside validation mode. The
model's prediction for the same window size, platform and device profile is
compared with the steady-state frame. The tools skip the first 20 frames of
each trace (startup); after that, at most one frame per scene differed from
the steady shape (e.g. 441 of 442 in `clip_savelayer` on macOS).

| Scene | macOS (M4 Max, Metal, fbf) | Pixel 10 (PowerVR, Vulkan, no fbf) |
| --- | --- | --- |
| plain | 1 pass ✓ | 1 ✓ |
| opacity_single (peephole) | 1 ✓ | 1 ✓ |
| opacity_overlap | 2 ✓ | 2 ✓ |
| clip_savelayer | 2 ✓ | 2 ✓ |
| backdrop_blur | 3 EntityPass + 3 blur ✓ | 7, sizes ✓ |
| two_backdrops | 5 + 6 ✓ | 12 ✓ |
| backdrop_group | 2 + 3 ✓ | 6 ✓ |
| image_filtered_blur | 2 + 3 ✓ | 5 ✓ |
| box_shadow (fast path) | 1 ✓ | 1 ✓ |
| saturation_blend | 1 + 1 blend snapshot ✓ | 5 full-screen ✓ |
| savelayer_blend | 2 ✓ | 5 ✓ |
| cupertino_alert (the talk's hook) | 3 + 1 input snapshot + 3 blur ✓ | 8, sizes ✓ |
| backdrop_sigma0 (blur dropped by the engine) | 1 ✓ | 1 ✓ |
| backdrop_in_layer (flip inside a saveLayer) | 4 + 3 ✓ | 7, sizes ✓ |

Full tables: `validation/results/macos.md`, `validation/results/pixel10.md`.
On macOS the comparison is the count of encoders per label plus whether the
frame ends with a blit (sizes are not in the trace); on the Pixel 10 it is
the multiset of pass sizes, within ±2 px (rounding of blur padding), with
order and labels not compared. The Pixel 10 log also confirms the sample
counts: EntityPass passes are 4× MSAA, blur passes 1×.

`validation/test/predict_test.dart` checks every prediction against the
committed `results/*.json` on each run, so a model change that contradicts a
measurement fails without a device.

### What validation changed

The first device runs did not all match. Fixing them made the model better
than the original prototype:

- With framebuffer fetch, an advanced blend first snapshots its source
  (`FramebufferBlendContents Snapshot`), an extra pass the prototype missed.
- Without it, the blend source is snapshotted (`AdvancedBlend(Src)`) before
  the `Advanced Blend Filter` pass.
- A color filter composed into a backdrop blur (`CupertinoAlertDialog`)
  renders its input first (`GaussianBlur` snapshot), sized to the coverage
  hint plus blur padding.
- The exact picture join exposed a test painter whose `shouldRepaint` hid
  stale pictures; the old forced-repaint capture had masked it.
- A blur with sigma 0 is dropped by the engine (`DlBlurImageFilter::Make`
  returns null), so a `BackdropFilter` animated to 0 is a plain layer, not
  a flip. The model predicted a flip until a review caught it; the
  `backdrop_sigma0` scene now confirms the fix on both devices.

The prototype's tests compared the model with expectations derived from the
model. The trace-validated claims now live in `validation/`, enforced by
`predict_test.dart`. `test/cases_test.dart` stays as fast model regression
tests: the cases that mirror a scene (backdrop blur, BackdropGroup, opacity
peephole and overlap, saveLayer clips, blends, the Cupertino dialog) expect
the pass counts the traces showed, and `predict_test.dart` holds the
measured sizes; the others (tight clips around backdrops, identity
matrix barriers, Cupertino bars, opacity over text, repaint boundaries) are
ported from engine logic and not traced. `test/memory_test.dart` checks the
traffic arithmetic at device preset sizes against the engine's formats and
MSAA storage.

### Not validated

- **iOS devices.** Not traced, by decision for this round. The `iosDevice`
  and `macos` capability profiles are identical (Metal, framebuffer fetch,
  `BGRA10_XR`), so the pass structure carries over. What differs on a phone
  is outside the profile: the onscreen surface is a `CAMetalLayer` drawable
  instead of the macOS embedder's IOSurface, and iOS may repaint only the
  damaged region. The `macos` profile also assumes a P3-capable display
  (wide gamut on); on an sRGB display macOS renders `BGRA8`.
- **The Metal blit path** (an offscreen frame copied to the screen with a
  blit) occurs on Metal without framebuffer fetch, i.e. the iOS Simulator.
  No traced scene exercises it.
- **OpenGL ES** (`olderAndroidGles`) and Vulkan devices *with* framebuffer
  fetch (`pixel9`, `galaxyS25`): ported, not traced.
- **Morphology and shader image filters, unusual mask blurs**: pass shapes
  are approximations and are flagged `approximate` in reports.
- **GPU time and energy**: not modeled. The `impeller_model-gpu-profiling`
  skill measures them.

## Memory

The prototype multiplied `w × h × 4 × (MSAA + 1)`. Both factors were wrong:

- **MSAA samples never reach memory.** Impeller's offscreen MSAA color is
  `StorageMode::kDeviceTransient` (memoryless on Apple GPUs) with store action
  `kMultisampleResolve` (`impeller/renderer/render_target.cc`): only the
  1-sample resolve texture is stored.
- **iOS renders 8 bytes per pixel.** Wide gamut is on by default
  (`FLTEnableWideGamut`), so the onscreen surface and offscreen textures are
  `BGRA10_XR`. The simulator uses `BGRA8`, Android Vulkan `RGBA8` (4 B/px).

The model now counts traffic, not allocation: each pass end stores its
texture once, each consumer reads it once, the blur downsample reads its
whole source. The **headline unit is the screen-equivalent**: bytes moved
divided by one full-screen write, shown as "× a plain frame". It does not
depend on pixel format, but it does depend on the device: screen size
changes blur and layer sizes relative to the screen, and devices without
framebuffer fetch add passes (the hook screen is 4.2× on iPhone 16, 4.1× on
Pixel 9, 6.1× on Pixel 10). Quote it per device. Bytes follow per device
(`ratio × width × height × B/px`).

Trade-offs, all deliberate:

- **Nominal bytes are an upper bound.** Impeller marks offscreen resolve
  textures as lossy-compressible on every backend. A15/M2 and newer Apple
  GPUs apply it (a Metal capture reports `allocatedSize` ≈ 0.52× nominal);
  Vulkan applies fixed-rate compression where the driver offers
  `VK_EXT_image_compression_control`. Most GPUs also compress losslessly.
  Compression ratios depend on content and are not public, so the model does
  not guess them; the report notes where they apply.
- **Partial repaint is not modeled.** iOS Metal may redraw only the damaged
  region (`kImpellerRepaintRatio` 0.7); macOS and Android redraw fully. A
  caret frame on iOS can be far cheaper than the full-frame estimate.
- **Caches, tile memory and glyph atlases** are out of scope.
- **Device classes, not devices.** Presets pair a `device_frame` screen with
  a capability profile. Framebuffer fetch is the biggest cost difference
  between classes (PowerVR lacks it; Adreno 650 and older fall back to GLES).

For the slides: a 1179×2556 iPhone texture is ≈ 12 MB at 4 B/px but
≈ 24 MB nominal at `BGRA10_XR`, before compression.

## Frame demand

`ImpellerModelBinding` overrides `scheduleFrame` and `scheduleFrameCallback`
and records a stack for every request; callbacks remember who scheduled
them, so a ticker's frame is attributed to the `State` that started it.
`measureFrameDemand` pumps fake time in vsync steps (after a settle period)
and records each frame, its sources, and whether its pictures differ from the
previous frame (op signatures). Given a device, it measures with that
device's platform (`debugDefaultTargetPlatformOverride`) and rebuilds the
tree first, because adaptive widgets decide per platform: a Material
`TextField` animates its caret every vsync on iOS and blinks it with a timer
on Android. `findTickers` reads every `State`'s ticker
diagnostics and resolves the owner widget's creation location.

Measured in tests: a repeating `AnimationController` requests 60/60 frames
and is attributed to its `State`; an iOS-style animated caret requests every
vsync with 104 of 120 frames identical, `cursorOpacityAnimates: false` drops
it to 2 frames per second; a `fixed_ticker` pulse at 10 fps requests 10
frames per second.

Limits: identical-frame detection compares recorded ops and paint
attributes; paths compare by identity, so a path rebuilt each frame counts as
changed. Video, platform views and external textures are invisible. Frames
requested from native code are not attributed.

## Naming

Passes carry the label Impeller gives them in a capture (`EntityPass Render
Pass`, `Gaussian Blur Filter`, `GaussianBlur`, `FramebufferBlendContents
Snapshot`, `AdvancedBlend(Src)`, ...; `engine/labels.dart`, each quoted), plus
a role with a plain title ("Offscreen frame", "Blur: downsample") and the
widget they are charged to with its creation location. The report's "Compare
with a GPU capture" panel lists the encoder labels to expect per frame.
Labels exist only in debug and profile builds (`IMPELLER_DEBUG`), and on
Vulkan only while validation layers run; the panel lists pass sizes there.

## Maintenance risk

Medium. The coupling is concentrated in `lib/src/engine/` (engine) and
`lib/src/capture/` (framework: `createCanvas`, `debugLayer`, layer fields,
`ImageFilter.toString()` for blur sigmas and the private compose filter).
On an SDK bump, `engine_refs.dart --diff-to <tag>` lists exactly the quoted
logic that changed, and the validation harness re-checks the result on
hardware in minutes. Only 3.47.1 has been validated. As a dry run,
`--diff-to 3.49.0-0.2.pre` lists every quoted file that changed and flags two
quotes (both in the widget creation-location lookup) for re-porting.

Fragile points to watch:

- Blur sigma and composed filters are read from `ImageFilter.toString()` and a
  dynamic field access; an engine change there makes filters `approximate`
  rather than wrong.
- The validation tools need Xcode (macOS) and an NDK plus a debuggable build
  (Android).

## What would make this robust

An engine-side counter would replace most of the model: a per-frame
`RenderPassCount` and `OffscreenBytes` in the raster timeline, or labels on
Vulkan release builds. Until then, the model plus a trace harness is the
cheapest reliable way to see passes before running on a device.
