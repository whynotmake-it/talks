# impeller_validation

Checks `impeeler`'s pass predictions against real GPU traces. Fourteen
scenes cover the engine rules the model ports (opacity peephole, saveLayer,
backdrop filters and groups, a blur dropped at sigma 0, a backdrop inside a
layer, image filters, shadows, advanced blends, the `CupertinoAlertDialog`
of the talk). Each scene redraws the same frame
continuously, so a trace holds hundreds of identical frames.

Results of the last run are committed in `results/`: 14/14 scenes match on
macOS (Apple M4 Max, Metal) and on a Pixel 10 (PowerVR, Vulkan).
`flutter test` checks every current prediction against them, so the model
cannot drift from the measurements unnoticed. `ios/` is there for a future
iPhone run; no iPhone has been traced yet.

## Run

Use the SDK the model is pinned to (`lib/src/engine/revision.dart`); set
`FLUTTER=/path/to/flutter` if it is not the `flutter` on `PATH`.

```sh
flutter test test/predict_test.dart        # predictions.json, checked against results/
dart run tool/validate.dart macos          # macOS: Metal System Trace per scene
dart run tool/validate_android.dart        # attached Android device
```

Both tools accept `--scene <name>` (trace a scene, keep the other
results) and `--no-build` (reuse the last build). They write
`results/<target>.md` and `.json`.

### macOS

Builds the profile app (fixed 400×800 pt window), launches each scene with
`IMPELLER_SCENE=<name>`, records Instruments' Metal System Trace headlessly
with `xctrace`, and groups render encoders per frame by time. Impeller labels
every encoder in debug and profile builds, so the comparison is the count of
encoders per label in the steady-state frame, plus whether the frame ends
with a blit to the screen. The first 20 frames are skipped as startup.
Needs Xcode and a P3 display (the built-in one), since the `macos` profile
assumes wide gamut.

### Android

Vulkan drivers expose no Impeller labels outside validation mode, so the
tool loads `tool/vk_pass_logger`, a small Vulkan layer that logs the size
and sample count of every `vkCmdBeginRenderPass` per present. It is compiled
with the newest NDK under `$ANDROID_HOME/ndk/` and copied into the app's data
directory, which Android allows only for debuggable apps: hence a debug
build (the pass structure does not depend on build mode). The tool turns on
GPU debug layers for this one app with `adb shell settings put global ...`
and deletes those settings when it exits. It wakes and unlocks the phone
before each scene (`wm dismiss-keyguard`, which works without a secure lock
screen) and stops with an error when a scene logs no frames. The comparison is pass count and
sizes (±2 px rounding) against the `pixel10` predictions; change
`predict_test.dart` to predict a different device.

## Adding a scene

Add it to `lib/scenes.dart`, rerun both steps, and commit the updated
`predictions.json` and `results/`. A mismatch is a model gap: fix the port
in `lib/src/engine/` (quoting the engine source) until the scene matches,
then add a regression case to the package's `test/cases_test.dart`.
