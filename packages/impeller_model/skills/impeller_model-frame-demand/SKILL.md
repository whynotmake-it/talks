---
name: impeller_model-frame-demand
description: >-
  Find what keeps a Flutter screen rendering while it looks idle, from a
  widget test with impeller_model: running tickers, repeating animations, a
  blinking caret, timers that call setState. Use when a static screen drains
  battery, runs hot or keeps the GPU busy; when asked to find running or
  leaked tickers or AnimationControllers; or when lowering the frame rate of a
  subtle, decorative or long-running animation (fixed_ticker).
---

# Find continuous frame demand with impeller_model

Every frame costs its full GPU work (see `impeller_model-gpu-cost`), so a
screen that requests a frame every vsync while nothing visibly changes pays
that cost 60–120 times a second. `measureFrameDemand` pumps fake time in
vsync steps and records each frame the app requests, who requested it, and
whether the frame drew anything new.

## Steps

### 1. Install the binding

Install `ImpellerModelBinding` in `test/flutter_test_config.dart` as step 1 of
the `impeller_model-gpu-cost` skill shows. Frame attribution needs it.

Done when the test suite runs with the binding.

### 2. Measure the idle screen

Pump the screen into the state the user leaves it in (the screen at rest, the
dialog open, the field focused), then:

```dart
final demand = await measureFrameDemand(tester);
```

It first pumps `settle` (500 ms) without recording, so entrance animations
end, then records `window` (1 s) at `refreshRate` (60 Hz). Pass a `device`
(`GpuDevice.iPhone16`) to measure as that device: the view is sized like it,
adaptive widgets build for its platform (the caret differs between iOS and
Android), and every frame's render passes are estimated. Without it the test
runs as Android, flutter_test's default. `estimateGpu` runs the same
measurement on its first device and puts it in the report.

Done when the measurement ran with the screen in the state under question.

### 3. Read the result

| Field | Meaning |
| --- | --- |
| `verdict` | `idle` (no frames), `periodic` (frames now and then: a timer caret), `continuous` (≥ 90 % of vsyncs: something animates). |
| `framesDrawn`, `vsyncSlots` | Frames requested vs. vsyncs in the window. |
| `unchangedFrames` | Frames whose pictures were identical to the previous frame: work with no visible result. |
| `sources` | Who requested the frames, grouped by class: `owner` (`EditableTextState (widgets/editable_text.dart)`), the stack `description`, and the first app frame `appFrame`. |
| `activeTickers` | Tickers that are running and not muted: `owner` widget, `ownerPath` (nearest ancestors), `ownerLocation` (where the closest app widget was created). |
| `stillRequesting` | A frame was still scheduled when the window ended: the demand does not stop on its own. |
| `renderPasses` | Estimated passes over the window, with `profile`. |

Done when every source and every active ticker is traced to a widget in the
user's code (`ownerLocation`, `appFrame`) or to a framework widget the user
placed (a text field, a progress indicator).

### 4. Remove or slow each source

Decide per source:

- **Not visible** (behind an opaque route, in an inactive tab, scrolled away,
  under `Offstage`): stop it. Routes covered by an opaque route are muted by
  the framework; widgets you hide yourself are not. Wrap them in
  `TickerMode(enabled: false)`, or stop the controller.
- **Decorative and endless** (pulse, shimmer, breathing glow, slow
  gradient): run it at a fixed lower rate with
  [`fixed_ticker`](https://pub.dev/packages/fixed_ticker): replace
  `SingleTickerProviderStateMixin` with `SingleFixedTickerProviderStateMixin`
  and return `TickerRate.fps(10)` from `tickerRate`, or wrap a subtree in
  `TickerRateScope(rate: TickerRate.fps(15), ...)`. Subtle and long
  animations look the same at 10–30 fps. In tests, use
  `pumpAndSettleFixedTickers()` from `package:fixed_ticker/testing.dart`
  instead of `pumpAndSettle()`. Alternatively, stop the animation after a few
  cycles.
- **A focused text field's caret**: `cursorOpacityAnimates: true` (the iOS
  default) fades the caret every vsync, and most of those frames are
  identical (measured: 104 of 120 in 2 s). `cursorOpacityAnimates: false`
  blinks it with a timer: 2 frames per second. Also avoid `autofocus` on
  fields the user may not type in, and unfocus when input is done.
- **Indeterminate progress indicators** animate every vsync until removed.
  Remove them as soon as the work ends; never leave one in a hidden widget.
- **Timers and streams calling `setState`**: the source's `appFrame` points at
  the call. Update only when the value changes, or at the rate a person can
  read (a clock: once per second).

Rerun the measurement after each change.

Done when the verdict is `idle`, or every remaining source is one the user
wants, with its frame rate stated.

### 5. Lock it in

```dart
expect(demand.verdict, FrameDemandVerdict.idle);
// or, for an intended slow animation:
expect(demand.framesDrawn, lessThanOrEqualTo(10));
```

Done when the test asserts the demand and passes.

## Limits

- Frame detection compares recorded pictures; video, platform views and
  external textures that update on their own are not seen.
- Frames requested from native code (platform channels, `Texture`) are not
  attributed.
- On iOS, partial repaint can redraw only the caret's region, so the GPU
  cost of a caret frame on a device can be far below the full-frame estimate.
  The frame still runs build, layout, paint and raster encoding. Measure on a
  device with `impeller_model-gpu-profiling` when the per-frame cost matters.
