/// How many frames a screen asks for when nobody touches it.
///
/// A widget test does not draw on its own clock: `pump` draws a frame only
/// if something scheduled one:
///
/// ```framework flutter_test/lib/src/binding.dart
///       if (hasScheduledFrame) {
///         _currentFakeAsync!.flushMicrotasks();
///         handleBeginFrame(Duration(microseconds: _clock!.now().microsecondsSinceEpoch));
/// ```
///
/// So pumping in vsync-sized steps and counting the frames that get drawn
/// measures exactly the frames the app requests: tickers, timers that call
/// `setState`, the text caret. Each frame is also checked for whether
/// anything visible changed.
library;

import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

import '../capture/binding.dart';
import '../capture/frame_requests.dart';
import '../capture/tickers.dart';
import 'frame_estimate.dart';
import 'gpu_device.dart';
import 'on_device.dart';

/// One frame drawn during the measurement window.
class FrameSample {
  FrameSample({
    required this.time,
    required this.changed,
    required this.picturesRecorded,
    required this.requestKeys,
    this.renderPasses,
  });

  /// Time since the window started.
  final Duration time;

  /// False when the layer tree and every recorded draw op are identical to
  /// the previous frame: a frame nobody can see.
  final bool changed;

  final int picturesRecorded;
  final List<String> requestKeys;

  /// Estimated render passes of this frame, when a device was given.
  final int? renderPasses;

  Map<String, Object?> toJson() => {
    'ms': time.inMicroseconds / 1000,
    'changed': changed,
    'pictures': picturesRecorded,
    if (renderPasses != null) 'renderPasses': renderPasses,
    'requests': requestKeys,
  };
}

/// Something that requested frames during the window.
class FrameSource {
  FrameSource(this.origin);
  final FrameRequestOrigin origin;

  /// Frames this source requested (a frame can have several sources).
  int frames = 0;

  /// Of those, frames whose output did not change.
  int unchangedFrames = 0;

  Map<String, Object?> toJson() => {
    ...origin.toJson(),
    'frames': frames,
    'unchangedFrames': unchangedFrames,
  };
}

enum FrameDemandVerdict {
  /// No frames requested: the screen costs nothing while idle.
  idle,

  /// Frames now and then, e.g. a caret toggled by a timer.
  periodic,

  /// A frame every vsync: something animates continuously.
  continuous,
}

class FrameDemand {
  FrameDemand({
    required this.window,
    required this.settle,
    required this.refreshRate,
    required this.frames,
    required this.sources,
    required this.tickers,
    required this.stillRequesting,
  });

  final Duration window;

  /// Fake time pumped before the window started.
  final Duration settle;

  /// The simulated display refresh rate (vsync slots per second).
  final int refreshRate;

  final List<FrameSample> frames;
  final List<FrameSource> sources;

  /// Tickers found in the widget tree at the end of the window.
  final List<TickerInfo> tickers;

  /// True if a frame or frame callback was still pending at the end.
  final bool stillRequesting;

  int get framesDrawn => frames.length;
  int get unchangedFrames => frames.where((f) => !f.changed).length;
  int get vsyncSlots =>
      (window.inMicroseconds * refreshRate / Duration.microsecondsPerSecond)
          .round();

  double get framesPerSecond =>
      framesDrawn * Duration.microsecondsPerSecond / window.inMicroseconds;

  /// Sum of estimated render passes over the window, when known.
  int? get renderPasses => frames.any((f) => f.renderPasses == null)
      ? null
      : frames.fold<int>(0, (a, f) => a + f.renderPasses!);

  FrameDemandVerdict get verdict {
    if (framesDrawn == 0) {
      return FrameDemandVerdict.idle;
    }
    return framesDrawn >= vsyncSlots * 0.9
        ? FrameDemandVerdict.continuous
        : FrameDemandVerdict.periodic;
  }

  List<TickerInfo> get activeTickers =>
      tickers.where((t) => t.requestsFrames).toList();

  Map<String, Object?> toJson() => {
    'windowMs': window.inMilliseconds,
    'settleMs': settle.inMilliseconds,
    'refreshRate': refreshRate,
    'verdict': verdict.name,
    'framesDrawn': framesDrawn,
    'unchangedFrames': unchangedFrames,
    'framesPerSecond': double.parse(framesPerSecond.toStringAsFixed(1)),
    if (renderPasses != null) 'renderPasses': renderPasses,
    'stillRequesting': stillRequesting,
    'sources': [for (final s in sources) s.toJson()],
    'tickers': [for (final t in tickers) t.toJson()],
    'frames': [for (final f in frames) f.toJson()],
  };
}

/// Pumps [window] of fake time in vsync steps of a [refreshRate] display
/// and records every frame the app requests.
///
/// First pumps [settle] of fake time without recording, so entrance and
/// focus animations that end on their own don't count. Use
/// `settle: Duration.zero` to measure a transition itself.
///
/// With [device], the test view is sized like it and set to its platform
/// for the measurement (adaptive widgets such as the text caret behave per
/// platform), and every frame's render passes are estimated for it.
/// Without it, the test runs as configured.
///
/// Advances the clock: animations move on during the window.
Future<FrameDemand> measureFrameDemand(
  WidgetTester tester, {
  Duration window = const Duration(seconds: 1),
  Duration settle = const Duration(milliseconds: 500),
  int refreshRate = 60,
  GpuDevice? device,
}) {
  if (device != null) {
    return onDevice(
      tester,
      device,
      () => _measure(tester, window, settle, refreshRate, device),
    );
  }
  return _measure(tester, window, settle, refreshRate, null);
}

Future<FrameDemand> _measure(
  WidgetTester tester,
  Duration window,
  Duration settle,
  int refreshRate,
  GpuDevice? device,
) async {
  final binding = ImpeelerBinding.instance;
  final step = Duration(
    microseconds: Duration.microsecondsPerSecond ~/ refreshRate,
  );
  final samples = <FrameSample>[];
  final sources = <String, FrameSource>{};
  var measuring = false;
  Object? previous;
  late DateTime start;

  // Listening already during the settle period records the frame callbacks
  // registered there, so the first frame of the window knows its source.
  final remove = binding.addFrameListener((frame) {
    if (!measuring) {
      return;
    }
    final capture = binding.captureFrame();
    final signature = capture?.root.signature;
    final changed = signature != previous;
    previous = signature;
    int? passes;
    if (device != null && capture != null) {
      passes = estimateFrame(capture, device).renderPasses;
    }
    final keys = <String>{};
    for (final r in frame.requests) {
      if (keys.add(r.key)) {
        final s = sources.putIfAbsent(r.key, () => FrameSource(r));
        s.frames++;
        if (!changed) {
          s.unchangedFrames++;
        }
      }
    }
    samples.add(
      FrameSample(
        time: binding.clock.now().difference(start),
        changed: changed,
        picturesRecorded: frame.picturesRecorded,
        requestKeys: keys.toList(),
        renderPasses: passes,
      ),
    );
  });

  try {
    for (var t = Duration.zero; t < settle; t += step) {
      await tester.pump(step);
    }
    previous = binding.captureFrame()?.root.signature;
    start = binding.clock.now();
    measuring = true;
    final slots = (window.inMicroseconds / step.inMicroseconds).round();
    for (var i = 0; i < slots; i++) {
      await tester.pump(step);
    }
  } finally {
    remove();
  }

  return FrameDemand(
    window: window,
    settle: settle,
    refreshRate: refreshRate,
    frames: samples,
    sources: sources.values.toList()
      ..sort((a, b) => b.frames.compareTo(a.frames)),
    tickers: findTickers(),
    stillRequesting:
        binding.hasScheduledFrame ||
        SchedulerBinding.instance.transientCallbackCount > 0,
  );
}
