# impeeler

Peels a frame apart to estimate the Impeller GPU work of a Flutter screen,
from a widget test:

- **Render passes per frame** and which widget caused each one
  (`BackdropFilter (lib/home.dart:42)`), named like Impeller labels them in a
  GPU capture.
- **Memory traffic** beyond a plain frame, per device class (iPhone, Pixel 9,
  Pixel 10, ...), in screen-equivalents and nominal bytes.
- **Frame demand**: the frames a screen keeps requesting while it looks idle
  (tickers, a blinking caret, timers), who requests them, and how many of
  them draw nothing new.

It is a thin peel of the Impeller engine — a model of one Flutter release
(3.47.1) — checked against real GPU traces on macOS Metal and a Pixel 10
(14/14 scenes each, see
[`validation/`](validation/README.md)). Treat it as an estimate that tells
you *whether a change adds or removes passes*; measure GPU time and energy on
a device.

## Agent skills

The pub package ships three skills for coding agents under `skills/`.
Start with `impeeler-gpu-cost`, which hands off to the other two:

| Skill | Use it to |
| --- | --- |
| [`impeeler-gpu-cost`](skills/impeeler-gpu-cost/SKILL.md) | Start here: estimate a screen's passes in a widget test, reduce costly widgets, and hand off to the other two. |
| [`impeeler-frame-demand`](skills/impeeler-frame-demand/SKILL.md) | Find what keeps an idle screen rendering; slow decorative animations with `fixed_ticker`. |
| [`impeeler-gpu-profiling`](skills/impeeler-gpu-profiling/SKILL.md) | Measure on a device: Xcode/Metal captures, Metal System Trace, energy; AGI, RenderDoc, Perfetto on Android. |

Install the package as a dev dependency, then install its bundled skills
with Dart's [`package:skills` tooling](https://dart.dev/ai/package-skills):

```sh
flutter pub add dev:impeeler@0.1.0-dev.2
dart run skills@ get -p impeeler
```

Run these commands from your Flutter project's directory. The skills command
reads the resolved dependency, prompts you to select skills, and installs them
into the appropriate directory for your coding agent. No Node.js or manual
pub-cache paths are needed.

To install all three skills without the skill-selection prompt:

```sh
dart run skills@ get -p impeeler --all
```

Run the same command after upgrading Impeeler to update the installed skills.
This also works when Impeeler is a local path dependency.

## Use

Add the package as a dev dependency (see
[Agent skills](#agent-skills) for the install command), then install the
binding in `test/flutter_test_config.dart`:

```dart
import 'dart:async';

import 'package:impeeler/impeeler.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  ImpeelerBinding.ensureInitialized();
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
`test/.impeeler/<test name>.{json,html,png}`. The HTML file shows:

- a screenshot of the screen,
- render passes and memory traffic per device, with a device picker,
- which widget causes them, with a fix,
- every pass of the selected device in order, with its size and cause,
- the frames drawn while idle as a strip (changed vs. unchanged), and what
  requested them,
- warnings when part of the estimate is a guess.

The labels to expect in a GPU capture are in the JSON.

Custom `Layer` subclasses that push their own clips or filters (for example
liquid_glass_renderer's `LiquidGlassCapture`) are read from the scene the
engine receives, so they count like the framework's layers.

See [`example/`](example/) for the talk's hook screen and a `fixed_ticker`
comparison; [`doc/hook_screen_with_the_name_dialog.html`](doc/hook_screen_with_the_name_dialog.html)
is the report it writes. Add `.impeeler/` to `.gitignore`.

### Lower-level API

| Call | Gives |
| --- | --- |
| `estimateGpu(tester, devices: [...])` | `GpuReport`: one `FrameEstimate` per device, `FrameDemand`, written files. |
| `estimateFrame(capture, device)` | One `FrameEstimate` from a `FrameCapture` of the last drawn frame (`ImpeelerBinding.instance.captureFrame()`). |
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

## Maintaining

Every engine decision the model mirrors is quoted from the pinned engine
source next to its port, and `dart run tool/engine_refs.dart` verifies the
quotes. Updating to a new Flutter release:
[`MAINTAINING.md`](MAINTAINING.md).

## License

Original Impeeler code is MIT-licensed (see [LICENSE](LICENSE)).
Portions that quote or adapt Flutter engine and framework source remain
under the BSD 3-Clause license; the upstream copyright notices are
included in [LICENSE](LICENSE).
