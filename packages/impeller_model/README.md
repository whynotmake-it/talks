# impeller_model

Estimates the Impeller GPU work of a Flutter screen from a widget test:

- **Render passes per frame** and which widget caused each one
  (`BackdropFilter (lib/home.dart:42)`), named like Impeller labels them in a
  GPU capture.
- **Memory traffic** beyond a plain frame, per device class (iPhone, Pixel 9,
  Pixel 10, ...), in screen-equivalents and nominal bytes.
- **Frame demand**: the frames a screen keeps requesting while it looks idle
  (tickers, a blinking caret, timers), who requests them, and how many of
  them draw nothing new.

It is a model of one Flutter release (3.47.1), checked against real GPU
traces on macOS Metal and a Pixel 10 (14/14 scenes each, see
[`validation/`](validation/README.md)). Treat it as an estimate that tells
you *whether a change adds or removes passes*; measure GPU time and energy on
a device.

## Use

```yaml
dev_dependencies:
  impeller_model:
    path: packages/impeller_model   # not published
```

Install the binding in `test/flutter_test_config.dart`:

```dart
import 'dart:async';

import 'package:impeller_model/impeller_model.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  ImpellerModelBinding.ensureInitialized();
  await testMain();
}
```

Then, in any widget test:

```dart
testWidgets('name dialog', (tester) async {
  await tester.pumpWidget(const HookApp());

  final report = await estimateGpu(tester, screenshot: true);

  for (final frame in report.frames) {
    expect(frame.renderPasses, lessThanOrEqualTo(8), reason: frame.device.name);
  }
  expect(report.frameDemand!.verdict, FrameDemandVerdict.continuous);
});
```

`estimateGpu` resizes the test view to each device, captures one frame per
device, watches frame demand for a second, and writes
`test/.impeller_model/<test name>.{json,html,png}`. The HTML file shows:

- render passes and memory traffic per device,
- which widget causes them, with a fix for each cause,
- the frames the screen draws while idle, and what requested them,
- warnings when part of the estimate is a guess,
- every pass in order with its size and cause, collapsed per device.

The labels to expect in a GPU capture are in the JSON.

Custom `Layer` subclasses that push their own clips or filters (for example
liquid_glass_renderer's `LiquidGlassCapture`) are read from the scene the
engine receives, so they count like the framework's layers.

See [`example/`](example/) for the talk's hook screen and a `fixed_ticker`
comparison; [`doc/hook_screen_with_the_name_dialog.html`](doc/hook_screen_with_the_name_dialog.html)
is the report it writes. Add `.impeller_model/` to `.gitignore`.

### Lower-level API

| Call | Gives |
| --- | --- |
| `estimateGpu(tester, devices: [...])` | `GpuReport`: one `FrameEstimate` per device, `FrameDemand`, written files. |
| `estimateFrame(capture, device)` | One `FrameEstimate` from a `FrameCapture` of the last drawn frame (`ImpellerModelBinding.instance.captureFrame()`). |
| `measureFrameDemand(tester)` | `FrameDemand`: verdict, frames, sources, tickers. |
| `findTickers()` | Every ticker in the tree, its owner widget and creation location. |
| `GpuDevice.iPhone16`, `.pixel10`, ..., `GpuDevice.custom(screen, gpu: ...)` | Device presets: a `device_frame` screen plus a `CapabilityProfile`. |

### Devices

| Preset | Backend | Framebuffer fetch | Bytes/px |
| --- | --- | --- | --- |
| `iPhone16`, `iPhone16Pro`, `iPhone16ProMax`, `iPhoneSE`, `iPadPro13` | Metal | yes | 8 (`BGRA10_XR`) |
| `iosSimulator` | Metal | no | 4 |
| `pixel9`, `galaxyS25` | Vulkan | yes | 4 |
| `pixel10` (PowerVR) | Vulkan | no | 4 |
| `olderAndroidGles` (Adreno 650 and older) | OpenGL ES | no | 4 |

`GpuDevice.phones` (the default) is iPhone 16, Pixel 9 and Pixel 10.

## Reading the numbers

- A plain frame is **1 render pass** and **1.0×** memory traffic.
- **× a plain frame** counts every offscreen texture write and read relative
  to one full-screen write. It does not depend on pixel format, but it does
  depend on the device (screen size, framebuffer fetch): compare per device.
- **MB** are nominal, `width × height × bytes/px` per write and read: an
  upper bound. MSAA samples are not counted (they never leave the GPU), iOS
  offscreen textures are 8 bytes per pixel, and A15/M2-and-newer Apple GPUs
  compress them lossily to about half.
- Not modeled: GPU time, partial repaint on iOS, raster cache, platform
  views, video and external textures.

[`FEASIBILITY.md`](FEASIBILITY.md) lists what was validated, how, and where
the model can be wrong.

## Agent skills

`skills/` ships three skills for coding agents (install with your agent's
skill tooling, or copy them into `.agents/skills/`):

| Skill | Use it to |
| --- | --- |
| [`impeller_model-gpu-cost`](skills/impeller_model-gpu-cost/SKILL.md) | Estimate a screen's passes in a widget test, read the report, and reduce costly widgets. |
| [`impeller_model-frame-demand`](skills/impeller_model-frame-demand/SKILL.md) | Find what keeps an idle screen rendering; slow decorative animations with `fixed_ticker`. |
| [`impeller_model-gpu-profiling`](skills/impeller_model-gpu-profiling/SKILL.md) | Measure on a device: Xcode/Metal captures, Metal System Trace, energy; AGI, RenderDoc, Perfetto on Android. |

## Maintaining

Every engine decision the model mirrors is quoted from the pinned engine
source next to its port, and `dart run tool/engine_refs.dart` verifies the
quotes. Updating to a new Flutter release:
[`MAINTAINING.md`](MAINTAINING.md).
