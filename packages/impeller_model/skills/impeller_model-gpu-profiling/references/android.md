# Android (Vulkan)

Commands and gotchas for measuring Impeller on Android. Flags and defaults were
checked against engine 3.47.1; device-side commands come from the linked
Android, Perfetto and Flutter docs.

## What you are measuring

On Android 10 (API 29) and newer, except on Vivante GPUs, the engine picks
Impeller and tries Vulkan first; when the device cannot run Vulkan
(missing Vulkan 1.1 or extensions, or a driver Impeller knows is bad, such
as Adreno 650 and older, or Pixel 10 drivers before 25.1), it falls back to
Impeller's OpenGL ES backend. Only older Android versions, Vivante GPUs and
apps that opt out render with the legacy Skia OpenGL renderer
(`shell/platform/android/flutter_main.cc` `SelectedRenderingAPI`,
`android_context_dynamic_impeller.cc`, `impeller/renderer/backend/vulkan/driver_info_vk.cc`
`IsKnownBadDriver`). The SDK's own
[android.md](https://github.com/flutter/flutter/blob/3.47.1/docs/engine/impeller/docs/android.md)
still describes the older Skia fallback.

- Confirm the backend in logcat or the `flutter run` output: the engine logs
  `Using the Impeller rendering backend (Vulkan).` or `(OpenGLES).`. On
  OpenGL ES, compare with `impeller_model`'s `olderAndroidGles` preset.
- Impeller is the default on API 29+
  ([Impeller docs](https://docs.flutter.dev/perf/impeller)), even though the
  `flutter run --help` text for `--enable-impeller` still calls it opt-in.
- Opt out for a comparison run: `flutter run --profile --no-enable-impeller`,
  or in `AndroidManifest.xml` under `<application>`:

  ```xml
  <meta-data
      android:name="io.flutter.embedding.android.EnableImpeller"
      android:value="false" />
  ```

- Try Impeller's own GLES backend (debug and profile only) with
  `io.flutter.embedding.android.ImpellerBackend` set to `opengles`
  ([Impeller README](https://github.com/flutter/flutter/blob/3.47.1/engine/src/flutter/impeller/README.md#android)).
- Engine flags set on the command line override the manifest. Put
  measurement-only metadata in `android/app/src/profile/AndroidManifest.xml` so
  it stays out of release
  ([Flutter-Android-Engine-Flags.md](https://github.com/flutter/flutter/blob/3.47.1/docs/engine/Flutter-Android-Engine-Flags.md)).
  RenderDoc drops `flutter run` flags when it launches the app, so use the
  manifest for it, and for any other tool that launches the app itself
  ([renderdoc_frame_capture.md](https://github.com/flutter/flutter/blob/3.47.1/docs/engine/impeller/docs/renderdoc_frame_capture.md)).
- Offscreen and onscreen color is `RGBA8`, 4 B/px.
- Flutter's `profile` build type is created with `initWith(debug)`
  ([FlutterPlugin.kt](https://github.com/flutter/flutter/blob/3.47.1/packages/flutter_tools/gradle/src/main/kotlin/FlutterPlugin.kt)),
  so profile APKs inherit the debug build type's debuggable flag, which AGI
  requires.

## Labels on Vulkan

Impeller names Vulkan objects and opens debug groups only while its Vulkan
validation is active
([context_vk.h](https://github.com/flutter/flutter/blob/3.47.1/engine/src/flutter/impeller/renderer/backend/vulkan/context_vk.h),
[command_buffer_vk.cc](https://github.com/flutter/flutter/blob/3.47.1/engine/src/flutter/impeller/renderer/backend/vulkan/command_buffer_vk.cc)).
That takes `flutter run --enable-vulkan-validation` (manifest key
`io.flutter.embedding.android.EnableVulkanValidation`) **and** a reachable
`VK_LAYER_KHRONOS_validation` layer. Stock engines do not bundle the layer
([android_validation_layers.md](https://github.com/flutter/flutter/blob/3.47.1/docs/engine/impeller/docs/android_validation_layers.md));
the AGI quickstart shows how to inject it with `adb shell settings` (below).
Keep timing runs separate from validated, labeled captures.

Without labels, identify passes by structure: attachment size (full-screen vs
downsampled blur passes), sample count (blur passes run without MSAA), and
order within the frame.

## Frame cadence and timeline: Perfetto

Record a system trace with Perfetto's helper script
([Perfetto: system tracing](https://perfetto.dev/docs/getting-started/system-tracing)):

```sh
curl -O https://raw.githubusercontent.com/google/perfetto/main/tools/record_android_trace
python3 record_android_trace -o trace_file.perfetto-trace -t 10s -b 32mb \
  -a '*' sched freq view ss input
```

The trace opens in the Perfetto UI when recording ends; `--no-open` skips that
on a remote machine.

- Flutter's timeline events reach the system trace only with
  `flutter run --profile --trace-systrace`; they then go to the system tracer
  instead of the DevTools timeline
  ([switch_defs.h](https://github.com/flutter/flutter/blob/3.47.1/engine/src/flutter/shell/common/switch_defs.h)).
  The manifest key is `io.flutter.embedding.android.TraceSystrace`.
- Per-frame GPU time from Impeller itself: set the manifest key
  `io.flutter.embedding.android.EnableVulkanGPUTracing` to `true` (manifest
  only, ignored in release). Impeller then records GPU timestamps per frame
  and emits a `GPUTracer` timeline counter with a `FrameTimeMS` value
  ([gpu_tracer_vk.cc](https://github.com/flutter/flutter/blob/3.47.1/engine/src/flutter/impeller/renderer/backend/vulkan/gpu_tracer_vk.cc),
  [FlutterEngineFlags.java](https://github.com/flutter/flutter/blob/3.47.1/engine/src/flutter/shell/platform/android/io/flutter/embedding/engine/FlutterEngineFlags.java)).
  `EnableOpenGLGPUTracing` does the same for Impeller GLES.

## GPU counters and system profile: AGI System Profiler

Android GPU Inspector needs a supported device on Android 11 or newer, `adb`,
and a debuggable app
([AGI quickstart](https://developer.android.com/agi/start),
[supported devices](https://developer.android.com/agi/supported-devices)).
Android emulators are not supported. The AGI docs now name Android
Performance Analyzer (public beta) as the recommended tool for system
profiling; this section covers AGI.

1. In AGI, Capture a new trace, select the device, type System profile, and
   your app's package as the application (without it the trace has no app
   ATrace markers or GPU activity).
2. Under Configure, enable GPU Counters, Frame Lifecycle and Renderstage
   slices; add Battery for a rough power estimate
   ([System Profiler](https://developer.android.com/agi/sys-trace/system-profiler)).
3. Reproduce the steady-state scenario for the trace duration.

The System Profiler is built on Perfetto; Frame Lifecycle traces SurfaceFlinger
events to find missed frames, and Renderstage slices show how the app uses the
GPU.

## One frame in detail: AGI Frame Profiler or RenderDoc

**AGI Frame Profiler** captures Vulkan calls, framebuffer content, draw calls,
memory, per-render-event GPU performance, pipelines, textures and shaders. Pick
the frame with Start and duration: Manual, Time (after N seconds) or Frame
(frame number)
([Frame Profiler](https://developer.android.com/agi/frame-trace/frame-profiler)).
For apps that use Vulkan directly, AGI requires the Vulkan validation layers
and no validation errors; the quickstart injects the layer from the AGI APK:

```sh
app_package=<your package>
abi=arm64v8a   # arm64v8a, armeabi-v7a or x86
adb shell settings put global enable_gpu_debug_layers 1
adb shell settings put global gpu_debug_app ${app_package}
adb shell settings put global gpu_debug_layer_app com.google.android.gapid.${abi}
adb shell settings put global gpu_debug_layers VK_LAYER_KHRONOS_validation

# afterwards
adb shell settings delete global enable_gpu_debug_layers
adb shell settings delete global gpu_debug_app
adb shell settings delete global gpu_debug_layers
adb shell settings delete global gpu_debug_layer_app
```

**RenderDoc** (Flutter's documented path, debug-mode app): install with
`flutter run`, set Impeller on or off in the manifest, connect RenderDoc to the
device per its Android how-to, pick the package from the Executable Path `...`
button, Launch, and capture a frame
([renderdoc_frame_capture.md](https://github.com/flutter/flutter/blob/3.47.1/docs/engine/impeller/docs/renderdoc_frame_capture.md),
[RenderDoc Android](https://renderdoc.org/docs/how/how_android_capture.html)).

Read a Vulkan capture with the same checklist as a Metal one
([apple.md](apple.md#reading-a-metal-capture)): render passes per frame,
attachment sizes, formats (`RGBA8`) and sample counts, load and store
operations, and draw counts per pass.

## Frame stats: dumpsys gfxinfo

```sh
adb shell dumpsys gfxinfo <package>
adb shell dumpsys gfxinfo <package> framestats
```

([dumpsys](https://developer.android.com/tools/dumpsys)). Android keeps these
render statistics for the `View`-based UI toolkit; apps that render through
their own Vulkan or OpenGL surface may not get them
([slow rendering](https://developer.android.com/topic/performance/vitals/render)).
Flutter renders its UI on its own raster thread, so check that the frame count
moves with your animation before using the numbers, and prefer the DevTools
frames chart or a Perfetto trace for Flutter frame times.

## Energy

- **Android Studio Power Profiler** shows On Device Power Rails Monitor (ODPM)
  data per rail, including GPU, Memory, Display and CPU clusters, on Pixel 6
  and later with Android 10 or newer; it records as part of a System Trace
  ([Power Profiler](https://developer.android.com/studio/profile/power-profiler)).
- **batterystats**
  ([dumpsys](https://developer.android.com/tools/dumpsys),
  [Batterystats](https://developer.android.com/topic/performance/power/setup-battery-historian)):

  ```sh
  adb shell dumpsys batterystats --reset
  # unplug, run the steady-state scenario for a fixed time, reconnect
  adb shell dumpsys batterystats --charged <package>
  adb shell dumpsys batterystats --checkin   # CSV
  ```

  Battery Historian is no longer maintained; Google points to system tracing,
  the Macrobenchmark power metric or the Power Profiler instead.
- For an A/B comparison keep device, brightness, duration and scenario fixed,
  record at least three runs per variant, and note the thermal conditions you
  can observe.
