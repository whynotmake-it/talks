# Apple: iOS and macOS (Metal)

Commands and gotchas for measuring Impeller's Metal backend. Headless commands
were run against a macOS profile build with Xcode 26 (`xcrun xctrace version`
26.0); iOS-device variants follow `xcrun xctrace help record` and
`man gpucapture`.

## Build and launch

- **iOS**: Impeller is the only renderer
  ([Impeller docs](https://docs.flutter.dev/perf/impeller)). On devices, wide
  gamut is on by default (`FLTEnableWideGamut`), so the layer and every
  offscreen texture are `BGRA10_XR`, 8 B/px. Install with
  `flutter install --profile -d <device>` or run with
  `flutter run --profile -d <device>`.
- **macOS**: Impeller is the default as of Flutter 3.47; `FLTEnableImpeller`
  set to `false` in `Info.plist` opts out
  ([Impeller docs](https://docs.flutter.dev/perf/impeller)). Wide gamut is on
  when the hardware supports it
  ([FlutterDartProject.mm](https://github.com/flutter/flutter/blob/3.47.1/engine/src/flutter/shell/platform/darwin/macos/framework/Source/FlutterDartProject.mm)).
  Build with `flutter build macos --profile`; the app lands in
  `build/macos/Build/Products/Profile/<App>.app`.
- **Xcode**: open `ios/Runner.xcworkspace` and run the Runner scheme
  ([native debugging](https://docs.flutter.dev/testing/native-debugging)). The
  Flutter template's scheme runs the Debug configuration and profiles
  (Product > Profile) with the Profile configuration; switch the Run action's
  build configuration to Profile in the scheme editor before a Metal capture you
  want to time.
- **GPU Frame Capture** is enabled automatically for targets that link Metal;
  if someone disabled it, re-enable it in the scheme editor: Run action,
  Options tab, GPU Frame Capture
  ([Apple](https://developer.apple.com/documentation/xcode/capturing-a-metal-workload-in-xcode)).

## Passes and GPU time over many frames: Metal System Trace

Headless recording, then the bundled script:

```sh
# macOS
xcrun xctrace record --template 'Metal System Trace' --time-limit 3s \
  --output t.trace --launch -- build/macos/Build/Products/Profile/App.app

# iOS device (profile build installed; device unlocked)
xcrun xctrace list devices
xcrun xctrace record --device <udid> --template 'Metal System Trace' \
  --time-limit 5s --output t.trace --launch -- <bundle id>

python3 <this skill>/scripts/metal_passes.py t.trace --top 3
```

The script prints frames, encoders per frame, GPU busy time per frame, the
label counts of the most common frame, and the most expensive frames with each
pass's GPU time in execution order:

```text
frames: 335 (gap 1.0 ms), encoders: 1981
encoders/frame: median 6, max 6
GPU busy ms/frame: median 0.378, max 1.434

most common frame (329 of 335 frames):
  3 x RenderPass & EntityPass Render Pass
  3 x RenderPass & Gaussian Blur Filter

top 1 frames by GPU busy time:
  frame 92 @ 1.890 s: 6 encoders, GPU busy 1.434 ms
       0.074 ms  EntityPass Command Buffer | RenderPass & EntityPass Render Pass
       0.082 ms  Command Buffer 0 | RenderPass & Gaussian Blur Filter
       0.575 ms  Command Buffer 0 | RenderPass & Gaussian Blur Filter
       0.121 ms  Command Buffer 0 | RenderPass & Gaussian Blur Filter
       0.330 ms  EntityPass Command Buffer | RenderPass & EntityPass Render Pass
       0.383 ms  EntityPass Command Buffer | RenderPass & EntityPass Render Pass
```

What the script relies on, for when you query tables yourself:

- `xcrun xctrace export --input t.trace --toc` lists the tables;
  `--xpath '/trace-toc/run[@number="1"]/data/table[@schema="<schema>"]'`
  exports one as XML. Values are interned: `id="N"` defines a value, `ref="N"`
  reuses it.
- `metal-application-encoders-list` has one row per encoder with the command
  buffer label and encoder label. Its duration is CPU encoding time, not GPU
  time. Its `Frame` column numbers command buffers, not Flutter frames.
- `metal-gpu-intervals` holds GPU execution intervals per channel (vertex,
  fragment, compute) for every process; join it to encoders on `encoder-id`.
- Encoders of one Flutter frame arrive in a burst, so group them by time gaps
  (`--gap-ms`, default 1 ms). Encoders are created ahead of execution; order by
  GPU start for execution order.
- `device-thermal-state-intervals` records the thermal state over the run.
- Labels are present in profile builds. When `xctrace` prints `Instruments will
  start recording when <device> is unlocked`, unlock the device; a trace
  recorded without a run fails to export with `run data is missing`.

In the Instruments UI, the display track shows frame cadence: a display
interval longer than its neighbours is a stutter, and the GPU track shows which
shader stage ran long
([Apple: analyzing Metal performance](https://developer.apple.com/documentation/xcode/analyzing-the-performance-of-your-metal-app)).

## One frame in detail: GPU frame capture

### Headless: gpucapture and gpudebug

`gpucapture` writes a `.gputrace` from a running process that was launched with
`MTL_CAPTURE_ENABLED=1`; `gpudebug` browses it from the terminal and is built
for agents (`man gpucapture`, `man gpudebug`,
[Apple: GPU issues with AI agents](https://developer.apple.com/documentation/xcode/investigating-gpu-issues-with-ai-agents)).

```sh
open -n --env MTL_CAPTURE_ENABLED=1 build/macos/Build/Products/Profile/App.app
gpucapture list                    # PID of the app
gpucapture boundaries --pid <pid>  # Device, Queue "Flutter Main Queue", Scope "Impeller Frame"
gpucapture start --pid <pid> --label "Flutter Main Queue" --count 12 --output f.gputrace
```

- Boundaries: `Impeller Frame` is a capture scope Impeller installs as the
  default scope and wraps around one frame when the engine renders to a
  `CAMetalLayer` or Metal texture
  ([context_mtl.mm](https://github.com/flutter/flutter/blob/3.47.1/engine/src/flutter/impeller/renderer/backend/metal/context_mtl.mm),
  [gpu_surface_metal_impeller.mm](https://github.com/flutter/flutter/blob/3.47.1/engine/src/flutter/shell/gpu/gpu_surface_metal_impeller.mm)).
  On iOS that makes `--label "Impeller Frame" --count 1` one Flutter frame
  (read from the engine source; check `gpucapture boundaries` shows a nonzero
  count first). On macOS
  its count stayed 0 (the desktop embedder takes another path), so capture the
  queue boundary with `--count` at least the command buffers of one frame
  (encoders per frame from `metal_passes.py`, plus one).
- The app has to render during the capture. A hidden or occluded macOS window
  stops producing frames and the capture sits at `0 / N MTLCommandBuffer`;
  bring the window to the front.
- iOS device: enable capture with the `MetalCaptureEnabled` Info.plist key
  ([Apple](https://developer.apple.com/documentation/xcode/capturing-a-metal-workload-programmatically))
  or launch with
  `xcrun devicectl device process launch --device <udid> -e '{"MTL_CAPTURE_ENABLED":"1"}' <bundle id>`.
  With Xcode running, `gpucapture list` also shows remote devices' processes;
  pass `--device <ID>`.

Browse the capture:

```sh
gpudebug -q -t f.gputrace -c "go /commands"     # prints "Session N created.", one cbN per command buffer
gpudebug -s N -c "go /commands/cb0"             # its encoders, e.g. re0 "EntityPass Render Pass"
gpudebug -s N -c "go /commands/cb0/re0"         # attachments and draw groups
gpudebug -s N -c "go /commands/cb0/re0" -c "info color0"
gpudebug --terminate N
```

Add `--json` for machine-readable output. The `performance` node needs a
profiling session (`profile ?` lists the commands).

### In Xcode

Run the app from Xcode, click the Metal Capture button in the debug bar, pick
the scope (`Impeller Frame` on iOS) and count, and click Capture. To capture an
app you did not launch from Xcode, use Debug > Debug Executable. Save with
File > Export
([Apple](https://developer.apple.com/documentation/xcode/capturing-a-metal-workload-in-xcode)).
Traces replay only on identical hardware and are large, so keep them local
([read_frame_captures.md](https://github.com/flutter/flutter/blob/3.47.1/docs/engine/impeller/docs/read_frame_captures.md)).

The Flutter team's walkthrough of the Xcode capture UI (overview, grouping by
pipeline state, bound resources, attachments, memory view, shader debugging)
is [read_frame_captures.md](https://github.com/flutter/flutter/blob/3.47.1/docs/engine/impeller/docs/read_frame_captures.md).
In the memory view, filter by resource name (`EntityPass`) to total the memory
of Impeller's offscreen textures.

## Reading a Metal capture

For each command buffer and render command encoder, check:

1. **Encoder label**: map it with the label table in `SKILL.md`. Trust encoder
   labels over command buffer labels: blur passes sit in their own command
   buffers, which Instruments shows as `Command Buffer 0`.
2. **Attachments**: color, depth and stencil, and the resolve texture (gpudebug
   lists it as `color10`). Example from the macOS capture of an offscreen
   EntityPass:

   ```text
   color0   "EntityPass Color Texture (Multisample)"  1600x1200 BGRA10_XR
   depth    "EntityPass Depth+Stencil Texture"        1600x1200 Depth32Float_Stencil8
   color10  "EntityPass Color Texture"                1600x1200 BGRA10_XR
   ```

3. **Load and store actions**: `info color0` on the MSAA attachment showed
   `loadAction: Clear`, `storeAction: MultisampleResolve`,
   `storageMode: Memoryless`, `sampleCount: 4`, `allocatedSize: 0 bytes`. The
   depth/stencil attachment was also memoryless with `storeAction: DontCare`.
   Only the resolve texture (`storageMode: Private`) reaches memory.
4. **Size and pixel format**: `BGRA10_XR` is 8 B/px. A pass with full-screen
   attachments is a full-screen write; a smaller one usually belongs to a
   filter (the blur downsamples).
5. **Allocated size**: Impeller requests lossy compression for resolve textures
   on Apple8-family GPUs and newer
   ([allocator_mtl.mm](https://github.com/flutter/flutter/blob/3.47.1/engine/src/flutter/impeller/renderer/backend/metal/allocator_mtl.mm)),
   so the 1600x1200 `BGRA10_XR` resolve texture above reported 7.55 MiB
   instead of the nominal 14.6 MiB.
6. **Draw groups** inside an encoder name what was drawn, for example
   `UberSDF`, `Texture Fill: MSAA backdrop`, `Texture Fill: Subpass`.

The onscreen pass on macOS used `ImpellerBackingStoreColorMSAA` (memoryless)
and `ImpellerBackingStoreResolve` attachments.

## Energy and thermal

- **Energy gauge**: run the app from Xcode on a device, then in the Debug
  navigator click Energy Impact. It shows average energy impact, a breakdown by
  category, and a timeline with the device's thermal condition
  ([Apple: battery use](https://developer.apple.com/documentation/xcode/analyzing-your-app-s-battery-use)).
- **Power Profiler** (iPhone with iOS 26 or later): Product > Profile, choose
  the Blank template, add the Power Profiler instrument, and pick your app
  rather than All Processes. It shows system power as a fraction of battery
  energy per hour, charger state, thermal state and display brightness, plus
  per-app lanes for CPU, GPU, display and networking
  ([Apple: Power Profiler](https://developer.apple.com/documentation/xcode/measuring-your-app-s-power-use-with-power-profiler)).
  Xcode 26 also lists a `Power Profiler` template in
  `xcrun xctrace list templates`, usable with
  `xcrun xctrace record --device <udid> --template 'Power Profiler' ...`.
- Gotchas from Apple's Power Profiler guide: while the device charges, system
  power reads 0, so pair over wireless debugging instead of a cable; power
  impact values are only comparable on the same device model; record several
  runs before and after a change. For unplugged sessions, record on the device
  with Settings > Developer > Performance Trace and open the file in
  Instruments.
- **Thermal**: the Metal System Trace table `device-thermal-state-intervals`
  and the Power Profiler track both record the thermal state; report it with
  every GPU time, since a throttled device changes the numbers.

For an A/B energy comparison keep device, brightness, duration and the
steady-state scenario fixed, and record at least three runs per variant.

## Flutter timeline events in Instruments

`--trace-systrace` sends Flutter's timeline to the system tracer instead of the
DevTools timeline
([switch_defs.h](https://github.com/flutter/flutter/blob/3.47.1/engine/src/flutter/shell/common/switch_defs.h)).
On Apple platforms the Dart VM emits them as `os_signpost` events with
subsystem `Dart` and one category per timeline stream; engine events such as
`Animator::BeginFrame`, `Rasterizer::DoDraw` and `GPURasterizer::Draw` are in
the `Embedder` category.

- `flutter run --profile --trace-systrace` (the flag's help names Android, iOS,
  macOS and Fuchsia).
- iOS without the tool: `FLTTraceSystrace` set to `YES` in `Info.plist`
  ([FlutterDartProject.mm](https://github.com/flutter/flutter/blob/3.47.1/engine/src/flutter/shell/platform/darwin/ios/framework/Source/FlutterDartProject.mm)).
- macOS without the tool: engine switches come from the environment in
  non-release builds
  ([engine_switches.cc](https://github.com/flutter/flutter/blob/3.47.1/engine/src/flutter/shell/platform/common/engine_switches.cc)):

  ```sh
  xcrun xctrace record --template 'Logging' --time-limit 3s --output l.trace \
    --env FLUTTER_ENGINE_SWITCHES=1 --env FLUTTER_ENGINE_SWITCH_1=trace-systrace \
    --launch -- build/macos/Build/Products/Profile/App.app
  xcrun xctrace export --input l.trace \
    --xpath '/trace-toc/run[@number="1"]/data/table[@schema="os-signpost"]'
  ```

  The `Logging` template recorded the `Dart` signposts; the `Metal System
  Trace` template recorded only Apple's own signposts in the same setup.

## Live overlay

`MTL_HUD_ENABLED=1` in the launch environment shows Apple's Metal performance
HUD on the app
([metal_validation.md](https://github.com/flutter/flutter/blob/3.47.1/docs/engine/impeller/docs/metal_validation.md)),
for example `xcrun xctrace record ... --env MTL_HUD_ENABLED=1` or
`open -n --env MTL_HUD_ENABLED=1 App.app`.
