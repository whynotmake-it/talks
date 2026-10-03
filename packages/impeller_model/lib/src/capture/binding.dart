import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_test/flutter_test.dart';

import 'layer_walk.dart';
import 'recorded_op.dart';
import 'recording_canvas.dart';

/// Everything captured for one painted frame.
class FrameCapture {
  FrameCapture({
    required this.root,
    required this.pictures,
    required this.physicalSize,
    required this.devicePixelRatio,
    required this.pictureMismatch,
  });

  /// Root of the layer tree (usually a TransformLayer carrying the
  /// devicePixelRatio scale).
  final CapturedLayer? root;

  /// Recorded op streams, in `createCanvas` order. PictureLayers reference
  /// these by index in layer-tree DFS order.
  final List<List<RecordedOp>> pictures;

  final Size physicalSize;
  final double devicePixelRatio;

  /// Non-null when the number of PictureLayers did not match the number of
  /// picture recordings (a join assumption failed — see FEASIBILITY.md).
  final ({int pictureLayers, int recorders})? pictureMismatch;
}

/// Test binding that instruments `RendererBinding.createCanvas`
/// (rendering/binding.dart:397) so every picture painted during a frame is
/// recorded through [RecordingCanvas].
///
/// Instantiate once before `testWidgets`:
/// ```dart
/// void main() {
///   FrameRecorderBinding();
///   testWidgets('...', (tester) async { ... });
/// }
/// ```
///
/// Capture semantics: `createCanvas` only fires when a picture is
/// (re)recorded. The layer tree a post-hoc `debugLayer` walk sees can drop
/// transient PictureLayers after compositing-bits updates, so
/// [captureFrame] forces a full repaint (marking every render object dirty)
/// before walking — ops and layers then correspond 1:1 in DFS order.
class FrameRecorderBinding extends AutomatedTestWidgetsFlutterBinding {
  static FrameRecorderBinding get instance =>
      WidgetsBinding.instance as FrameRecorderBinding;

  final OpRecorderRegistry opRegistry = OpRecorderRegistry();
  final LayerWalker walker = LayerWalker();

  // ---- frame-request counting (the "frames per second" factor) ----

  /// Times `SchedulerBinding.scheduleFrame` was called. With fake time this
  /// is the closest analog to "frames requested" — note that a real device's
  /// vsync cadence does not apply in widget tests (every `pump` draws).
  int framesRequested = 0;

  /// Attribution for [framesRequested]: counts keyed by the outermost stack
  /// frame outside the binding/scheduler (typically the Ticker or animation).
  final Map<String, int> frameRequesters = <String, int>{};

  int framesDrawn = 0;

  /// drawFrames that recorded at least one picture — the closest widget-test
  /// analog to "frames that actually painted" (a drawFrame with zero
  /// recordings means nothing repainted, only retained content).
  int framesPainted = 0;

  void _countFrameRequest() {
    framesRequested++;
    final lines = StackTrace.current.toString().split('\n');
    for (final line in lines) {
      if (!line.contains('impeller_model') &&
          !line.contains('scheduler/binding.dart') &&
          !line.contains('ticker.dart') &&
          line.contains('package:')) {
        final m = RegExp(r'\((.*)\)').firstMatch(line);
        frameRequesters[m?.group(1) ?? line.trim()] =
            (frameRequesters[m?.group(1) ?? line.trim()] ?? 0) + 1;
        return;
      }
    }
    frameRequesters['unknown'] = (frameRequesters['unknown'] ?? 0) + 1;
  }

  /// Count of `scheduleFrameCallback` registrations — this is what
  /// `Ticker.scheduleTick` calls each tick (ticker.dart:299). Each entry is
  /// a frame request by an animation/ticker; key = owning stack frame.
  final Map<String, int> tickerRequests = <String, int>{};

  @override
  void scheduleFrame() {
    _countFrameRequest();
    super.scheduleFrame();
  }

  @override
  void scheduleForcedFrame() {
    _countFrameRequest();
    super.scheduleForcedFrame();
  }

  @override
  int scheduleFrameCallback(
    ui.FrameCallback callback, {
    bool rescheduling = false,
    bool scheduleNewFrame = true,
  }) {
    final lines = StackTrace.current.toString().split('\n');
    for (final line in lines) {
      if (!line.contains('impeller_model') &&
          !line.contains('scheduler/binding.dart') &&
          !line.contains('ticker.dart') &&
          line.contains('package:')) {
        final m = RegExp(r'\((.*)\)').firstMatch(line);
        final key = m?.group(1) ?? line.trim();
        tickerRequests[key] = (tickerRequests[key] ?? 0) + 1;
        break;
      }
    }
    return super.scheduleFrameCallback(
      callback,
      rescheduling: rescheduling,
      scheduleNewFrame: scheduleNewFrame,
    );
  }

  @override
  void drawFrame() {
    framesDrawn++;
    // Each painted frame gets a fresh set of recordings; captureFrame forces
    // a full repaint so the registry is complete after pump.
    opRegistry.clear();
    super.drawFrame();
    if (opRegistry.pictures.isNotEmpty) {
      framesPainted++;
    }
  }

  @override
  ui.Canvas createCanvas(ui.PictureRecorder recorder) {
    final inner = super.createCanvas(recorder);
    final index = opRegistry.newRecorder();
    return RecordingCanvas(inner, opRegistry.pictures[index]);
  }

  /// Capture one frame.
  ///
  /// When [repaintAll] is true (the default), every render object in the view
  /// is marked dirty and a frame is pumped, so all pictures are re-recorded
  /// and the walked layer tree exactly matches the recorded op streams.
  /// When false, the last painted frame is captured as-is (picture ops of
  /// retained repaint boundaries may be missing; check
  /// [FrameCapture.pictureMismatch]).
  Future<FrameCapture> captureFrame(
    WidgetTester tester, {
    bool repaintAll = true,
  }) async {
    if (repaintAll) {
      _markTreeNeedsPaint(RendererBinding.instance.renderView);
      await tester.pump();
    }
    final rootLayer = RendererBinding.instance.renderView.debugLayer;
    final root = rootLayer == null
        ? null
        : walker.walk(rootLayer, pictureCount: opRegistry.pictures.length);
    return FrameCapture(
      root: root,
      // Copy: the registry is cleared and repopulated by every drawFrame —
      // holding the registry's own list would silently empty captures.
      pictures: List.of(opRegistry.pictures),
      physicalSize: tester.view.physicalSize,
      devicePixelRatio: tester.view.devicePixelRatio,
      pictureMismatch: walker.mismatch == null
          ? null
          : (
              pictureLayers: walker.mismatch!.expectedLayers,
              recorders: walker.mismatch!.recorders,
            ),
    );
  }

  void _markTreeNeedsPaint(RenderObject node) {
    if (!node.attached) {
      return;
    }
    node.markNeedsPaint();
    node.visitChildren(_markTreeNeedsPaint);
  }
}
