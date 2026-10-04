# Maintaining impeller_model

The model mirrors engine and framework internals that are not stable API, so
it is pinned to one Flutter release (`lib/src/engine/revision.dart`) and
built to make an SDK upgrade a mechanical review.

## Layout

| Directory | Contents | Coupled to |
| --- | --- | --- |
| `lib/src/engine/` | Ports of Impeller and DisplayList decisions: `canvas.dart` (`Canvas` save/restore/flip), `display_list.dart` (layer tree to ops, `dl_builder` bookkeeping), `dl_dispatcher.dart`, `gaussian_blur.dart`, `color_filter.dart`, `capabilities.dart` (formats, framebuffer fetch per backend), `labels.dart` (debug labels). | Engine source |
| `lib/src/capture/` | `ImpellerModelBinding`: canvas and scene recording, layer walk, frame-request attribution, ticker discovery, widget creation locations. | Framework internals (`createCanvas`, `createSceneBuilder`, `debugLayer`, layer fields and `engineLayer`, `Ticker` diagnostics) |
| `lib/src/model/` | Memory traffic arithmetic over the pass list. | Engine types only (`ModelPass`), no engine logic |
| `lib/src/api/` | Public API: `estimateGpu`, `measureFrameDemand`, device presets, JSON/HTML report. | `flutter_test` pumping (`frame_demand.dart`), per-platform widget defaults (`on_device.dart`), both quoted |
| `tool/engine_refs.dart` | Quote checker and upgrade diff. | |
| `validation/` | Device harness: scenes, predictions, macOS and Android tracers. | |

Only `lib/src/engine/` and `lib/src/capture/` should change when the engine
changes.

## The quote convention

Every decision ported from the engine or framework carries the source it was
read from, in a fenced block inside a Dart comment:

```dart
// ```engine impeller/display_list/canvas.cc
//   if (can_distribute_opacity && !backdrop_filter &&
//       Paint::CanApplyOpacityPeephole(paint) &&
// ```
```

- `engine` paths are relative to `<sdk>/engine/src/flutter/`, `framework`
  paths to `<sdk>/packages/`.
- Quote the lines that make the decision, verbatim (whitespace may differ).
  No line numbers: they rot; the checker finds the text.
- A port without a quote is a guess: mark it `approximate` in the pass it
  produces.

`dart run tool/engine_refs.dart` checks every quote against the pinned SDK
(it looks in `~/fvm/versions/<pinned>` or takes `--flutter-root`). It must
report all quotes found.

## Upgrading Flutter

Follow the steps in
[`.agents/skills/impeller_model-engine-upgrade/SKILL.md`](.agents/skills/impeller_model-engine-upgrade/SKILL.md)
(written so an agent can run it; it reads the same for a person).

## Validation

A model change is done when `flutter test` passes and the device scenes in
`validation/` still match: run them on macOS and on a Vulkan device without
framebuffer fetch (the Pixel 10) as `validation/README.md` describes. Device
mismatches are model bugs; fix the port, then add a regression case to
`test/cases_test.dart` with the measured numbers in a comment.
