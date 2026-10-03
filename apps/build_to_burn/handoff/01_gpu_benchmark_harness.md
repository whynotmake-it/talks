# Handoff: Flutter GPU benchmark harness + agent skill

You are building the deliverable we promised at the end of our Fluttercon 2026 talk "Build to Burn" (Jesper Bellenbaum, Tim Lehmann). Read this whole document before writing code.

## Mission

Ship an open-source tool that lets any Flutter developer:

1. Describe a **user journey** in their own app as a test (integration_test first, Patrol as a stretch).
2. Run that journey in **profile mode on a real Android and a real iOS device**, while the platform's own tracers record it: Perfetto on Android, Instruments via `xctrace` on iOS.
3. Collect **as many GPU-relevant metrics as possible**: frame build time, raster-thread time, real GPU time, idle frames, GPU counters, power, thermal state, and memory.
4. Reduce the result to a **small, structured findings file**, so any coding agent can reason about it. Keep the full traces next to it for humans.
5. Use an **agent skill** that reads the findings, explains them, compares a before run with an after run, and tells the user which single frame to capture in Xcode or Android GPU Inspector for a deeper look.

The talk's thesis is what this tool should make measurable: **GPU work = frames per second × cost per frame.** DevTools shows the symptom. Platform tools show the cost. The most important metric we teach is **idle frames per second**: frames produced while the user does nothing (no input for about 2 s). A healthy screen is near 0. A screen with a focused iOS text field (animated caret) and a backdrop blur sits at the refresh rate.

The talk deck already sketches the skill as `/frame-autopsy`. Scripts do the counting (Perfetto SQL and xctrace exports). The model explains a small findings file. The skill names which frame to capture. Keep that split: **never feed raw traces to the model.**

## Ground rules

- **Read the manual first.** Before using any API, tool or flag, read its official documentation for the version in use. Where docs and the source disagree, the source wins, and you note the discrepancy. Do not answer from memory, and do not trial-and-error.
- **Flutter version:** 3.47, the local SDK at `/Users/jesper/Development/SDKs/flutter` (commit `d3b14c87690`, includes `engine/src/flutter` and `docs/`). Verify behavior in that source and cite `file:line` in your design notes.
- **Never present an estimate as a measurement.** Every number in the findings file carries its source: which counter, which tool, which device.
- **Ask the humans** (Jesper, Tim) before anything outward-facing: creating repos, publishing packages, changing the talk deck.

## Verified facts to build on (research from 2026-10-03)

These were checked against the local SDK and official docs. Re-verify anything you depend on.

### Flutter side

- **Profiling cookbook:** https://docs.flutter.dev/cookbook/testing/integration/profiling
  - On the test side, `IntegrationTestWidgetsFlutterBinding.traceAction(action, {streams, retainPriorEvents, reportKey})`.
  - The driver uses `integrationDriver(responseDataCallback: …)` → `Timeline.fromJson` → `TimelineSummary.summarize` → `writeTimelineToFile`.
  - Run with `flutter drive --driver=test_driver/perf_driver.dart --target=integration_test/x_test.dart --profile`. Add `--no-dds` on mobile devices.
  - `flutter test integration_test` **always forces debug mode** (`packages/flutter_tools/lib/src/commands/test.dart:434`). Profile mode needs `flutter drive`.
- **Timeline summary has real GPU time** (`packages/flutter_driver/lib/src/driver/timeline_summary.dart:370`).
  - `average|90th|99th|worst_gpu_frame_time` come from the `GPUTracer` counter, argument `FrameTimeMS` (`gpu_sumarizer.dart:13`).
  - It also has `*_gpu_memory_mb`, build and rasterizer percentiles, missed budgets, vsync lag, refresh-rate histograms, and GC counts.
  - Optional `cpu_usage` / `gpu_usage` / `memory_usage` exist only on iOS.
  - Only the `traceAction` path gets GPU numbers. `watchPerformance` uses `FrameTiming` and has none.
- **"Raster" is CPU time, everywhere.** The DevTools raster bar, `FrameTiming.rasterDuration` and `frame_rasterizer_*` all measure raster-**thread** CPU time, not GPU time. Name metrics accordingly.
- **Android GPU timing is off by default.** It needs the manifest meta-data `io.flutter.embedding.android.EnableVulkanGPUTracing = true`. It can't be set from the CLI. Devicelab injects it in `dev/devicelab/lib/tasks/perf_tests.dart:848`.
- **iOS GPU timing is on in profile builds.** `GPUTracerMTL` reads `MTLCommandBuffer` GPU start/end times. It is compiled under `IMPELLER_DEBUG`, which covers debug and profile but not release.
- **Tracing flags** on `flutter run` / `flutter drive`: `--trace-systrace`, `--trace-to-file`, `--endless-trace-buffer`, `--trace-startup`, `--trace-allowlist`, `--enable-impeller`.
- **Getting engine events into Perfetto on Android:** use `--trace-systrace`, or start Perfetto with `atrace_apps: "<package>"` before the app launches, in which case the engine switches to systrace by itself.
- **Debug flags for extra trace detail:** `debugProfileBuildsEnabled`, `debugProfileLayoutsEnabled`, `debugProfilePaintsEnabled` and `debugEnhancePaintTimelineArguments` add per-widget/per-render-object timeline events and dirty lists. They are usable from a test.
- **Threads:** the UI and platform threads are merged on Android and iOS. Expect UI work on the main thread. The raster thread is `io.flutter.raster` on iOS.
- **Impeller render pass labels** (in captures, profile builds): `EntityPass Root Render Pass`, `EntityPass Render Pass`, `Gaussian Blur Filter`.

### Android

- **Perfetto from the CLI:**
  - `record_android_trace -c cfg.pbtx -o out.perfetto-trace --no-open`, or `adb shell perfetto --txt -c - -o /data/misc/perfetto-traces/x` with `--background-wait` or `--detach/--attach`.
  - Analysis: `pip install perfetto` → `TraceProcessor(trace=…).query(sql)`.
- **Data sources to try:**
  - **GPU:** `gpu.renderstages` and `gpu.counters`, with vendor-suffixed names that must match exactly (for example `gpu.counters.adreno`, `gpu.renderstages.mali`); `vulkan.memory_tracker`.
  - **ftrace:** `power/gpu_frequency`, `gpu_mem/gpu_mem_total`, `thermal/thermal_temperature`.
  - **Frames:** `android.surfaceflinger.frametimeline` (Android 12+).
  - **Power:** `android.power` with battery counters (Android 10+, mostly Pixel), power rails/ODPM (rare on production phones), energy estimation.
  - Discover what a device offers with `adb shell perfetto --query`.
- **Device hygiene:**
  - `adb shell cmd power set-fixed-performance-mode-enabled true` (devicelab `toggleFixedPerformanceMode`).
  - Battery current is distorted while USB-charging. Power rails are not.
- **Profile APKs are debuggable** (the Gradle profile build type does `initWith(debug)`).
- **AGI / APA:** Android GPU Inspector is being superseded by Android Performance Analyzer (public beta, May 2026). Neither has a documented CLI, so treat them as "capture this frame by hand" targets for the skill.
- **Reuse:** Google publishes an `android-profiler` agent skill (github.com/android/skills, `profilers/android-profiler`) that records traces and writes PerfettoSQL. Study it before writing your own.

### iOS

- **`xctrace`:**
  - Record: `xcrun xctrace record --template 'Metal System Trace' --device <UDID> --attach <pid|name> --time-limit 30s --output x.trace`. Other templates: `Power Profiler`, `Game Performance`, `Animation Hitches`. Useful instruments include `Thermal State`, `Metal GPU Counters`, `Display`, `os_signpost`.
  - Export: `xctrace export --input x.trace --toc`, then `--xpath` on a table schema.
- **Metal GPU counters are off by default.** In the GUI they're enabled under Recording Options → Counter Set → "Performance Limiters". The `--recording-options` JSON keys for that are **unverified**.
- **Power Profiler:**
  - Needs iOS/iPadOS 26+.
  - Reports **0 while the device is charging**, so use wireless pairing.
  - "All Processes" gives no per-app values.
  - Values are not comparable across device models.
- **MetricKit** `MXGPUMetric` is a daily histogram, so it's useless per run.
- In-app thermal state: `ProcessInfo.thermalState`.
- Developer Mode is required on the device.

### Traps the design must handle

1. **System tracing breaks the VM timeline.** When the app traces to systrace (Perfetto `atrace_apps`, or `--trace-systrace`), Dart timeline events go to the system tracer, and `getVMTimeline` / `getPerfettoVMTimeline` fail with RPCError 114. So `traceAction` and system-level app tracing cannot run in the same session. Options:
   - Run **two passes**: pass 1 is `traceAction` (Flutter summary plus GPU frame time); pass 2 is Perfetto/xctrace with app events.
   - Or run Perfetto **without** `atrace_apps` alongside `traceAction`, and correlate by timestamps.
   - Decide this in a spike (milestone M0), and document the choice.
2. **Patrol** (`patrol test --profile` works) uses `PatrolBinding extends LiveTestWidgetsFlutterBinding`. It has no `traceAction`, no `reportData` and no host driver. Supporting Patrol means talking to vm_service yourself, or relying only on external traces.
3. **Power and battery readings lie while charging,** on both platforms.
4. **Thermal state changes results.** Record it at the start and end, enforce a cooldown between runs, and repeat each run N times.

## Proposed architecture

You may change this if the M0 spike shows a better shape. Write down why.

**A Dart package, `journey_bench`** (name is a placeholder):
- A test-side API that wraps `IntegrationTestWidgetsFlutterBinding`.
  - `benchJourney('name', (tester) async { … })`.
  - Phase markers (`await bench.phase('open search sheet')`) emitted as timeline events, so traces can be cut per phase.
  - A built-in `idle(Duration(seconds: 3))` phase that measures idle frames per second.
- It sets the enhanced-tracing debug flags when requested.

**A CLI runner** (Dart, `dart run journey_bench:run`):
- Detects the platform and device.
- Prepares the build: Android manifest key for GPU tracing, profile mode, Impeller on.
- Applies device hygiene and records device metadata: model, SoC, OS, Flutter version, refresh rate, thermal state, battery level and charging state.
- Starts the native tracer with a checked-in config per platform, runs the journey via `flutter drive --profile`, stops the tracer, and pulls all artifacts.
- Supports `--runs N` and `--cooldown`.

**An analyzer** (Python with `perfetto` trace_processor for Android; `xctrace export` + a parser for iOS) that writes:
- `findings.json`: the compact, versioned schema the skill reads. Include per phase:
  - frames/s and idle frames/s
  - build, raster-CPU and GPU time percentiles
  - missed budgets
  - the share of frames where raster time exceeds build time, and of frames that painted nothing (where measurable)
  - GPU frequency and counters
  - power and thermal slope
  - the top N worst frames, with timestamps, so the skill can say "capture frame #123"
- `report.md`: human-readable, with the device footer the talk demands (device and SoC, OS, Flutter version, build mode, refresh rate, thermal state, duration, number of runs, metric source). **Never print a bare "GPU %".**

**An agent skill** (`SKILL.md` plus scripts, agent-agnostic Markdown; must work in Claude Code):
- Runs or ingests a benchmark.
- Explains `findings.json` in plain language.
- Ranks likely causes using the talk's model:
  - idle frames first: animated caret, `TickerMode`, hidden spinners
  - then cost per frame: backdrop blurs, Cupertino bars' built-in blur, advanced blend modes on devices without framebuffer fetch, saveLayers
- Has a **compare mode** for a before run and an after run.
- Names exactly which frame or time window to capture in Xcode or AGI/APA, and how.

## Milestones

- **M0, spike (time-boxed).** On one Android device (Pixel preferred) and one iPhone:
  - Prove that you can get `gpu_frame_time` from `traceAction`, a Perfetto trace with GPU frequency/counters, and an xctrace Metal System Trace from one CLI command each.
  - Resolve the RPCError 114 trap (two passes vs. no `atrace_apps`), and resolve the xctrace counter-set options.
  - Write `docs/M0-findings.md` listing what worked, with exact commands.
- **M1:** Android end-to-end: runner, analyzer and `findings.json`.
- **M2:** iOS end-to-end.
- **M3:** agent skill with explain and compare modes.
- **M4:** example app and validation (see below), README, and a recorded demo run.
- **Stretch:** Patrol support; `--trace-startup` journeys; CI recipe (for example Firebase Test Lab for Android).

## Validation (acceptance criteria)

Use the talk's demo as the ground truth: a blue page, a frosted card (`ClipRRect` r=24 + `BackdropFilter` blur σ=10), and a focused `CupertinoTextField`. Also use `apps/build_to_burn/scratch_book/blend_vs_backdrop.dart` from the talk repo.

- On an iPhone at 120 Hz, the idle phase with the focused field shows idle frames/s near the refresh rate. With `cursorOpacityAnimates: false` it drops to about 2/s.
- Removing the blur lowers GPU frame time per frame, but not frames/s.
- The skill, given before and after `findings.json` files, correctly attributes the change to frame count vs. cost per frame.
- Every number in `report.md` has a source. The device footer is complete.
- The tool works from a clean clone with documented prerequisites. Nothing is hard-coded to Jesper's machine.

## Open questions to answer and document

- Does `FLTTraceSystrace` in an iOS app's Info.plist really route engine events to os_signpost, so they're visible in Instruments? This was inferred from source and is untested.
- Does `xctrace --attach` work against a Flutter profile build without extra entitlements?
- Do `gpu.renderstages` and `gpu.counters` require a debuggable app on every vendor?
- Do Flutter frames show up correctly in Android FrameTimeline?
- Which power signal is trustworthy on which devices, and how do you detect "not trustworthy" at runtime?

## Report back

At each milestone: what works, the exact commands, what failed and why, the decisions you took, and the open questions. Keep `docs/` in the repo current, so the next agent can pick up from it.
