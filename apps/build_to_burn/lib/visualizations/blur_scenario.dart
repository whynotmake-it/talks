import 'package:flutter/foundation.dart';

/// How a focused text field's caret produces frames.
enum CaretMode {
  /// The field isn't focused: no caret, no ticker, no frames.
  none(0, 'No focus'),

  /// The iOS default (`cursorOpacityAnimates: true`): the caret fades on an
  /// `AnimationController`, whose ticker asks for a frame every vsync.
  fading(120, 'Fading caret'),

  /// `cursorOpacityAnimates: false`, and the Android default: the caret
  /// blinks on a 500 ms timer, two frames per second.
  blinking(2, 'Blinking caret');

  const CaretMode(this.framesPerSecond, this.label);

  /// Frames the caret makes the app produce per second, at 120 Hz.
  final int framesPerSecond;

  final String label;
}

/// One state of the search-sheet repro: is the sheet a backdrop blur, and
/// how does its caret tick.
@immutable
class BlurScenario {
  const BlurScenario({
    required this.blur,
    required this.caret,
    required this.caption,
  });

  /// Whether the sheet is a `BackdropFilter` blur (otherwise an opaque sheet).
  final bool blur;

  final CaretMode caret;

  /// One or two sentences that explain the state.
  final String caption;

  int get framesPerSecond => caret.framesPerSecond;

  /// Render passes per frame on mobile Impeller: one onscreen pass, plus
  /// about 4 for a backdrop blur (pass break, 3 blur passes, restart). Count
  /// them in a Metal capture before quoting on stage.
  int get passesPerFrame => blur ? 5 : 1;

  /// The talk's aha, one scenario per deck step.
  static const ahaSequence = [
    BlurScenario(
      blur: true,
      caret: CaretMode.fading,
      caption:
          'The caret repaints one tiny rect. But every tick is a new frame, '
          'and every frame re-renders the whole screen, blur included.',
    ),
    BlurScenario(
      blur: true,
      caret: CaretMode.none,
      caption:
          'Unfocus the field: no ticker, no frames. An idle screen costs no '
          'GPU work, blur or not.',
    ),
    BlurScenario(
      blur: false,
      caret: CaretMode.fading,
      caption:
          'Drop the blur, keep the caret: still a full-screen frame every '
          'vsync, but each one is much cheaper.',
    ),
    BlurScenario(
      blur: true,
      caret: CaretMode.blinking,
      caption:
          'Keep the blur, set cursorOpacityAnimates: false. The caret blinks '
          'on a timer: two frames per second.',
    ),
  ];

  @override
  bool operator ==(Object other) =>
      other is BlurScenario && other.blur == blur && other.caret == caret;

  @override
  int get hashCode => Object.hash(blur, caret);
}
