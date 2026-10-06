---
name: impeeler-gpu-profiling
description: >-
  Measure Impeller GPU work of a Flutter app on real hardware: Metal frame
  captures (Xcode, gpucapture, gpudebug), Instruments Metal System Trace and
  Power Profiler, Android GPU Inspector, RenderDoc, Perfetto, dumpsys. Use when
  profiling GPU time, raster-thread jank, battery drain or thermal state on an
  iOS, macOS or Android device; when capturing or reading a GPU frame capture;
  when finding which frame is expensive; or when checking an impeeler
  estimate against a device.
---

# Impeller GPU profiling on a device

This skill produces **ground truth**: render passes, attachments, GPU time and
energy measured on a physical device running a profile build. Estimates come
from the sibling skills: `impeeler-gpu-cost` (render passes from a widget
test) and `impeeler-frame-demand` (continuously requested frames). Use
this skill when the answer has to come from hardware:

- confirm the passes Impeller really encodes for a screen,
- measure GPU time per frame and frame cadence over time,
- measure energy and thermal state, or compare two variants of a screen,
- check whether an `impeeler` estimate matches the device.

Sources are linked inline. The Flutter team's capture guides ship in the Flutter
SDK under `docs/engine/impeller/docs/` (pinned 3.47.1 copies:
[read_frame_captures.md](https://github.com/flutter/flutter/blob/3.47.1/docs/engine/impeller/docs/read_frame_captures.md),
[xcode_frame_capture.md](https://github.com/flutter/flutter/blob/3.47.1/docs/engine/impeller/docs/xcode_frame_capture.md),
[renderdoc_frame_capture.md](https://github.com/flutter/flutter/blob/3.47.1/docs/engine/impeller/docs/renderdoc_frame_capture.md)).
Labels and defaults below were checked against engine 3.47.1.

## Ground rules

These hold for every branch.

- **Profile build, physical device.** Debug mode and simulators/emulators are
  not indicative of release performance
  ([Flutter performance profiling](https://docs.flutter.dev/perf/ui-performance)).
  The iOS Simulator also renders BGRA8 (4 B/px) without framebuffer fetch,
  where an iOS device renders BGRA10_XR (8 B/px), so its passes and bytes differ.
- **Know the backend.** The engine logs `Using the Impeller rendering backend
  (Metal).` / `(Vulkan).` / `(OpenGLES).` at startup. Android devices that
  cannot run Vulkan fall back to Impeller's OpenGL ES backend
  ([android.md](references/android.md#what-you-are-measuring)).
- **Labels.** Metal captures carry Impeller's labels in debug and profile
  builds. Vulkan captures carry them only while Impeller's Vulkan validation is
  active (see [android.md](references/android.md#labels-on-vulkan)).
- **Steady state.** Make the expensive frame repeat (keep the dialog open, loop
  the animation) so every frame in a trace is the frame you care about and any
  capture boundary lands on it.
- **Write down the context** with every number: device model, OS, build mode,
  backend, display refresh rate, and whether the device was charging.

## Steps

### 1. Pick the question and the tool

| Question | iOS / macOS (Metal) | Android (Vulkan) |
| --- | --- | --- |
| Which frame is expensive? | DevTools Performance view (step 3) | same |
| Passes and GPU time over many frames | Metal System Trace + `scripts/metal_passes.py` | Perfetto, AGI System Profiler |
| One frame in detail: passes, attachments, formats, load/store | `gpucapture` + `gpudebug`, or Xcode Metal capture | AGI Frame Profiler, RenderDoc |
| Energy and thermal | Xcode Energy gauge, Power Profiler | Android Studio Power Profiler, `dumpsys batterystats` |

Then read the platform reference for the tool's commands and gotchas:
[references/apple.md](references/apple.md) for iOS and macOS,
[references/android.md](references/android.md) for Android.

Done when you can state the question in one sentence and have picked the
device, the tool and the platform reference.

### 2. Build and launch

```sh
flutter run --profile -d <device>      # iOS, Android, macOS
flutter install --profile -d <device>  # install only, for tools that launch the app themselves
flutter build macos --profile          # -> build/macos/Build/Products/Profile/<App>.app
```

Done when the app runs in profile mode on the physical device, the backend log
line matches what you intend to measure, and the scenario reproduces.

### 3. Find the expensive frame

Skip this step when the user already names the frame or interaction.

1. With the profile build running, open DevTools from the URL `flutter run`
   prints and go to the Performance view
   ([docs](https://docs.flutter.dev/tools/devtools/performance)). The Flutter
   frames chart shows one UI bar and one Raster bar per frame; frames over the
   frame budget are marked as jank.
2. Select a janky frame and read the Timeline events tab. Classify it:
   - **UI bar long**: Dart build/layout/paint cost. Profile the Dart code
     first; the GPU is not the bottleneck yet.
   - **Raster bar long**: the raster thread, where Impeller encodes the frame,
     is slow. It runs on the CPU, so it bounds CPU encode time; GPU execution
     time needs step 4.
   - **Frames short but continuous while nothing moves**: frame demand, which
     the sibling skills above cover.
3. Optional quick A/B in the same view: the More debugging options toggles
   (Render Clip layers, Render Opacity layers, Render Physical Shape layers).
   If raster time drops with one off, that effect drives the cost
   ([docs](https://docs.flutter.dev/tools/devtools/performance)).
4. Turn the frame into a steady state. If it can only happen once (first open,
   a route transition), record a system trace across the interaction, rank
   frames by GPU time (`metal_passes.py --top`, or the AGI/Perfetto frame
   tracks) and capture with a count that covers the window.
5. To line up DevTools frames with a system trace, put Flutter's timeline
   events into the system trace with `--trace-systrace`
   ([apple.md](references/apple.md#flutter-timeline-events-in-instruments),
   [android.md](references/android.md#frame-cadence-and-timeline-perfetto)).
   Otherwise match frames by their pass pattern and order.

Done when you can name the expensive frame (interaction and screen state), say
whether UI or raster dominates, and either reproduce it as a steady state or
know its time window in a trace.

### 4. Measure

Run the tool from step 1 as the platform reference describes.

Done when you have, for the frame in question: the ordered list of render
passes with labels (or structural identities on unlabeled Vulkan captures),
each pass's color attachment size, format and sample count, and, depending on
the question, GPU time per frame over at least a few hundred frames, or energy
over at least three runs per variant.

### 5. Read the result and compare with the estimate

Map each pass to its cause with the label table in
[references/captures.md](references/captures.md). When an estimate from
`impeeler-gpu-cost` exists for the same screen, compare per frame:

- pass count by label (each Gaussian blur is three passes),
- offscreen texture sizes and formats, and bytes per pixel from the same
  reference,
- whether the frame ends with a copy to the onscreen texture (Impeller rendered
  offscreen first).

To compare many scenes at once, the package's `validation/` app automates
this: `tool/validate.dart` records a Metal System Trace per scene on macOS
and compares encoder labels; `tool/validate_android.dart` loads a small Vulkan
layer into a debug build that logs every render pass's size, which needs no
Impeller labels. See `validation/README.md`.

Done when every measured pass is attributed to a label and a cause, and every
difference from the estimate is listed with its likely reason: different
device capabilities, simulator vs device, or a model gap.

### 6. Report

Example values from a macOS run of a rotating box under a `BackdropFilter` blur:

```text
Device / OS:           Apple M4 Max, macOS 27.0.1, on power
Build / backend:       profile, Impeller Metal, wide gamut on
Scenario:              rotating box under a BackdropFilter blur, steady state
Passes per frame:      6 = 3 x EntityPass Render Pass, 3 x Gaussian Blur Filter
Offscreen textures:    EntityPass Color Texture 1600x1200 BGRA10_XR (+ memoryless 4x MSAA)
GPU busy per frame:    median 0.38 ms, max 1.43 ms over 335 frames
Energy / thermal:      <tool, runs, values, charging yes/no>
Estimate vs measured:  <matches | differences and reasons>
```

Done when the report holds every line above that applies to the question, and
the trace or capture files are saved next to it.
