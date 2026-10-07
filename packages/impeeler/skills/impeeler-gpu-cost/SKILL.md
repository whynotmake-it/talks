---
name: impeeler-gpu-cost
description: >-
  Start here for Flutter GPU cost. Estimate and reduce the Impeller GPU cost
  of a Flutter screen from a widget test with impeeler: render passes,
  offscreen textures and memory traffic per device class, and hand off to
  impeeler-frame-demand (how often it renders) and impeeler-gpu-profiling
  (device measurements). Use when a screen uses BackdropFilter, blur,
  frosted glass, Opacity, saveLayer, ShaderMask, ImageFiltered, ColorFiltered,
  advanced blend modes or Cupertino dialogs and sheets; when asked why a
  static screen is expensive, drains battery or runs hot; or when adding a
  GPU budget to a test.
---

# Estimate a screen's GPU cost with impeeler

`impeeler` replays the frames of a widget test through a port of
Impeller's pass logic (Flutter 3.47.1) and reports, per device class, the
render passes a frame splits into, which widget caused each one, and the
memory traffic beyond a plain frame. It is an **estimate**: the pass
structure was checked against real GPU traces on macOS Metal and a Pixel 10
(see the package's `FEASIBILITY.md`), but bytes are nominal and GPU time is
not modeled. The ground truth is a device capture: the
`impeeler-gpu-profiling` skill.

This is the entry skill; it routes to the others:

- Cost per frame: this skill.
- How often frames happen (tickers, carets, timers): `impeeler-frame-demand`.
- GPU time, energy or a capture on hardware: `impeeler-gpu-profiling`.

A frame that idles at 60 or 120 Hz pays its cost on every vsync. When the
question is *how often* a screen renders, use `impeeler-frame-demand`;
`estimateGpu` reports both.

## Steps

### 1. Install the binding

Add the package as a dev dependency and install `ImpeelerBinding` in
`test/flutter_test_config.dart`, so it is in place before the first test:

```dart
import 'dart:async';

import 'package:impeeler/impeeler.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  ImpeelerBinding.ensureInitialized();
  await testMain();
}
```

It replaces `AutomatedTestWidgetsFlutterBinding`; ordinary widget tests keep
working, and their own `TestWidgetsFlutterBinding.ensureInitialized()` calls
return it. Only a binding installed before the config runs (for example
`IntegrationTestWidgetsFlutterBinding` in an integration test) makes
`ImpeelerBinding.ensureInitialized()` throw a `StateError` naming it.

Done when `flutter test` runs with the config file and the existing tests pass.

### 2. Pump the screen in the state to measure

Write a `testWidgets` that builds the real screen with its real widgets and
brings it into the state under question: dialog open, sheet expanded, field
focused. Pump until entrance animations end (`pumpAndSettle` unless something
animates forever; then `pump(const Duration(seconds: 1))`). Then:

```dart
final report = await estimateGpu(tester, screenshot: true);
```

`estimateGpu` sizes the test view like each device in `devices` (default
`GpuDevice.phones`: iPhone 16, Pixel 9, Pixel 10) and sets its platform, so
adaptive widgets build as on that device, captures one frame per device,
then watches frame demand for one second on the first. It writes
`<test name>.json`, `.html` and (with `screenshot`) `.png` to
`test/.impeeler/`. Other presets are on `GpuDevice` (iPhone SE/Pro
Max, iPad Pro 13", iOS Simulator, Galaxy S25, an OpenGL ES phone);
`GpuDevice.custom(screen, gpu: CapabilityProfile...)` pairs any
`device_frame` screen with a GPU profile.

Done when the report files exist and the screenshot shows the intended state.

### 3. Read the report

Open the `.html` file, or read the `FrameEstimate`s in `report.frames`.
[references/reading-the-report.md](references/reading-the-report.md) defines
every number and pass role. In order:

1. **Render passes** (`renderPasses`): a plain frame has 1. Each extra pass
   is stored to memory and read back.
2. **Cost centers** (`costCenters`): passes and bytes charged to the widget
   that caused them, with its creation location (`BackdropFilter
   (lib/home.dart:42)`), most expensive first.
3. **Pass timeline** (`passes`): each pass with its size, role, Impeller label
   and the reason it exists (`cause`, `endedBy`).
4. **Devices**: compare the columns. Devices without framebuffer fetch (Pixel
   10, OpenGL ES, the iOS Simulator) split extra passes for blends and
   backdrops.

Done when you can name, for the worst device, every cost center and why its
passes exist, in the user's widget terms.

### 4. Reduce the cost

Apply the patterns in
[references/reducing-cost.md](references/reducing-cost.md). Each one names
the engine rule it relies on. Change one thing, rerun the test, compare the
report. Keep the visual result unless the user agrees to trade it.

Done when every cost center was either reduced, or kept with a stated reason
(the effect is the design), and the before/after pass counts are reported.

### 5. Lock in a budget

Assert on the estimate so regressions fail the test:

```dart
for (final frame in report.frames) {
  expect(frame.renderPasses, lessThanOrEqualTo(3), reason: frame.device.name);
}
```

Prefer pass counts and `traffic.relativeToPlainFrame` over bytes: they do not
change with pixel format or compression.

Done when the test asserts the budget and passes.

### 6. Confirm on a device when it matters

When a decision depends on real GPU time or energy, or the report marks a pass
`approximate`, measure with `impeeler-gpu-profiling`. The report's
"Compare with a GPU capture" panel lists what to expect per frame: encoder
labels on Metal, pass sizes on Vulkan.

Done when the decision either does not depend on GPU time, energy or an
`approximate` pass, or the device measurement is reported next to the
estimate.

## When the estimate is uncertain

- `approximate: true` on a pass: a filter the model does not port in detail
  (shader image filters, morphology sizes, unusual mask blurs).
- `missingPictures > 0`: some drawing was not recorded; the estimate is
  missing those draws. Report it.
- Platform views, video and external textures are invisible to the model.
- The model pins one Flutter release (`pinnedFlutterVersion`). On a
  different SDK, read [references/engine-source.md](references/engine-source.md)
  before trusting a result that depends on a changed rule.
