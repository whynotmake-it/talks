---
name: impeeler-engine-upgrade
description: Move impeeler to a new Flutter release and re-verify it against the engine source and real GPU traces.
disable-model-invocation: true
---

# Upgrade impeeler to a new Flutter release

Run from `packages/impeeler`. `OLD` is `pinnedFlutterVersion` in
`lib/src/engine/revision.dart`, `NEW` the target tag (e.g. `3.48.0`). The
package's conventions are in `MAINTAINING.md`.

## 1. Find what changed

```sh
git -C <OLD sdk checkout> fetch --tags origin
dart run tool/engine_refs.dart --diff-to NEW
```

The tool lists every quoted file that changed between `OLD` and `NEW` and,
per quote, whether its text still exists at `NEW`. Also read the diff of the
directories the model depends on but quotes only in part:

```sh
git -C <sdk> diff OLD NEW --stat -- engine/src/flutter/impeller/display_list \
  engine/src/flutter/impeller/entity engine/src/flutter/display_list \
  engine/src/flutter/flow/layers packages/flutter/lib/src/rendering/layer.dart
```

Done when every vanished quote and every changed decision in those
directories is listed with the Dart port it affects (search
`lib/` for the quote's path).

## 2. Re-port

For each listed change, read the new engine code, update the port in
`lib/src/engine/` or `lib/src/capture/`, and replace the quote with the new
source text. Changed debug labels go into `lib/src/engine/labels.dart`.

Done when `dart run tool/engine_refs.dart --flutter-root <NEW sdk>` reports
every quote found.

## 3. Bump the pin

Set `pinnedFlutterVersion` and `pinnedEngineRevision` (from
`bin/internal/engine.version` of `NEW`) in `lib/src/engine/revision.dart`,
the `flutter:` constraint in `pubspec.yaml`, `example/pubspec.yaml` and
`validation/pubspec.yaml`, and the version mentioned in the skills under
`skills/`.

Done when `flutter analyze` is clean and `flutter test` passes with the `NEW`
SDK in the package, `example/` and `validation/`.

## 4. Re-validate on devices

As `validation/README.md` describes: regenerate `predictions.json`, then run
`tool/validate.dart macos` and `tool/validate_android.dart` with a Pixel 10
attached.

Done when both `results/*.md` report every scene matching. A mismatch sends
you back to step 2 for that rule.

## 5. Record

Update the validation section of `FEASIBILITY.md` with the new results and
any rule that changed.

Done when the results, `FEASIBILITY.md` and the pin are committed together.
