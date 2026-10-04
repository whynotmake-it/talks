/// The test binding that records every picture the framework paints and
/// watches who requests frames.
library;

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_test/flutter_test.dart';

import 'frame_requests.dart';
import 'layer_walk.dart';
import 'recorded_op.dart';
import 'recording_canvas.dart';
import 'scene_recording.dart';

/// Everything captured for one frame: the composited layer tree with every
/// picture's recorded ops attached.
class FrameCapture {
  FrameCapture({
    required this.root,
    required this.physicalSize,
    required this.devicePixelRatio,
    required this.missingPictures,
    this.sceneLayers = const {},
    this.unmodeledLayers = const {},
  });

  /// Root of the layer tree (a TransformLayer carrying the device pixel
  /// ratio).
  final CapturedLayer root;

  final Size physicalSize;
  final double devicePixelRatio;

  /// PictureLayers whose picture was not recorded through the binding, so
  /// their draws are unknown to the model. 0 in normal widget tests.
  final int missingPictures;

  /// Custom layer types read from the pushes they sent to the engine.
  final Set<String> sceneLayers;

  /// Custom layer types whose effect is unknown; estimated as plain
  /// containers.
  final Set<String> unmodeledLayers;
}

/// What happened in one drawn frame, reported to frame listeners.
class DrawnFrame {
  DrawnFrame({
    required this.timeStamp,
    required this.requests,
    required this.picturesRecorded,
  });

  /// Fake-clock time of the frame.
  final Duration timeStamp;

  /// Why the frame was drawn: the request that scheduled it, plus every
  /// ticker callback that ran in it.
  final List<FrameRequestOrigin> requests;

  /// Pictures re-recorded in this frame (0 means nothing repainted).
  final int picturesRecorded;
}

/// The `flutter_test` binding for impeller_model.
///
/// Install it before the first `testWidgets`, either in the test's `main`
/// or once for all tests in `test/flutter_test_config.dart`:
///
/// ```dart
/// Future<void> testExecutable(FutureOr<void> Function() testMain) async {
///   ImpellerModelBinding.ensureInitialized();
///   await testMain();
/// }
/// ```
///
/// It wraps every picture recorder and canvas the framework creates, using
/// the hooks the framework provides for exactly this:
///
/// ```framework flutter/lib/src/rendering/binding.dart
///   /// Create a [PictureRecorder].
///   ///
///   /// This hook enables test bindings to instrument the rendering layer.
/// ```
///
/// Each finished picture is mapped to its recorded ops by identity, so a
/// layer tree walk finds the exact ops of every PictureLayer, including
/// retained ones painted in earlier frames.
class ImpellerModelBinding extends AutomatedTestWidgetsFlutterBinding {
  ImpellerModelBinding._();

  /// Returns the binding, creating it if no binding exists yet.
  ///
  /// Throws a [StateError] when another binding is already installed:
  /// call this before any `testWidgets` runs.
  // Mirrors the `XBinding.ensureInitialized()` convention of Flutter bindings.
  // ignore: prefer_constructors_over_static_methods
  static ImpellerModelBinding ensureInitialized() {
    if (_instance != null) {
      return _instance!;
    }
    try {
      final existing = WidgetsBinding.instance;
      throw StateError(
        'A ${existing.runtimeType} is already installed. Call '
        'ImpellerModelBinding.ensureInitialized() before the first '
        'testWidgets, e.g. at the top of main() or in '
        'test/flutter_test_config.dart.',
      );
      // WidgetsBinding.instance throws when no binding exists yet.
      // ignore: avoid_catching_errors
    } on FlutterError {
      // No binding yet.
    }
    return _instance = ImpellerModelBinding._();
  }

  static ImpellerModelBinding? _instance;

  /// The installed binding.
  static ImpellerModelBinding get instance {
    final i = _instance;
    if (i == null) {
      throw StateError(
        'ImpellerModelBinding is not installed. Call '
        'ImpellerModelBinding.ensureInitialized() before the first '
        'testWidgets.',
      );
    }
    return i;
  }

  final Expando<List<RecordedOp>> _opsByPicture = Expando('recorded ops');

  final Expando<SceneNode> _sceneByEngineLayer = Expando('scene node');

  SceneNode? _lastScene;

  late final LayerWalker _walker = LayerWalker(
    (p) => _opsByPicture[p],
    sceneFor: (e) => _sceneByEngineLayer[e],
    lastScene: () => _lastScene,
  );

  @override
  ui.SceneBuilder createSceneBuilder() => RecordingSceneBuilder(
    super.createSceneBuilder(),
    _sceneByEngineLayer,
    (scene) => _lastScene = scene,
  );

  int _picturesThisFrame = 0;

  @override
  ui.PictureRecorder createPictureRecorder() =>
      _RecordingPictureRecorder(super.createPictureRecorder(), _opsByPicture);

  @override
  ui.Canvas createCanvas(ui.PictureRecorder recorder) {
    if (recorder is _RecordingPictureRecorder) {
      _picturesThisFrame++;
      return RecordingCanvas(super.createCanvas(recorder.inner), recorder.ops);
    }
    return super.createCanvas(recorder);
  }

  /// Walks the current layer tree, i.e. the last frame drawn.
  ///
  /// Returns null before the first frame.
  FrameCapture? captureFrame() {
    final rootLayer = renderView.debugLayer;
    if (rootLayer == null) {
      return null;
    }
    final root = _walker.walk(rootLayer);
    return FrameCapture(
      root: root,
      physicalSize: renderView.flutterView.physicalSize,
      devicePixelRatio: renderView.flutterView.devicePixelRatio,
      missingPictures: _walker.missingPictures,
      sceneLayers: Set.of(_walker.sceneLayers),
      unmodeledLayers: Set.of(_walker.unmodeledLayers),
    );
  }

  // ------------------------------------------------------- frame requests

  final List<void Function(DrawnFrame frame)> _frameListeners = [];

  /// Calls [listener] after every frame drawn until the returned callback
  /// is called.
  VoidCallback addFrameListener(void Function(DrawnFrame frame) listener) {
    _frameListeners.add(listener);
    return () => _frameListeners.remove(listener);
  }

  bool get _recording => _frameListeners.isNotEmpty;

  FrameRequestOrigin? _scheduledBy;
  final List<FrameRequestOrigin> _tickerCallbacks = [];

  /// Origin of each frame callback, keyed by the callback. A ticker
  /// re-registers the same tear-off every frame, which compares equal, so
  /// its start stack names it on every later tick.
  final Map<Function, FrameRequestOrigin> _callbackOrigins = {};

  void _noteScheduleFrame() {
    // Only the call that actually schedules the frame is its cause.
    //
    // ```framework flutter/lib/src/scheduler/binding.dart
    //   void scheduleFrame() {
    //     if (_hasScheduledFrame || !framesEnabled) {
    //       return;
    //     }
    // ```
    if (_recording && !hasScheduledFrame && framesEnabled) {
      _scheduledBy = FrameRequestOrigin.fromStack(StackTrace.current);
    }
  }

  @override
  void scheduleFrame() {
    _noteScheduleFrame();
    super.scheduleFrame();
  }

  @override
  void scheduleForcedFrame() {
    _noteScheduleFrame();
    super.scheduleForcedFrame();
  }

  /// Tickers register `_tick` every frame; a reschedule happens inside the
  /// previous tick:
  ///
  /// ```framework flutter/lib/src/scheduler/ticker.dart
  ///     _animationId = SchedulerBinding.instance.scheduleFrameCallback(
  ///       _tick,
  ///       rescheduling: rescheduling,
  ///       scheduleNewFrame: false,
  ///     );
  /// ```
  @override
  int scheduleFrameCallback(
    ui.FrameCallback callback, {
    bool rescheduling = false,
    bool scheduleNewFrame = true,
  }) {
    final origin = rescheduling
        ? _callbackOrigins[callback]
        : FrameRequestOrigin.fromStack(StackTrace.current);
    if (origin != null) {
      _callbackOrigins[callback] = origin;
      if (_recording) {
        _tickerCallbacks.add(origin);
      }
    }
    return super.scheduleFrameCallback(
      callback,
      rescheduling: rescheduling,
      scheduleNewFrame: scheduleNewFrame,
    );
  }

  @override
  void postTest() {
    super.postTest();
    _callbackOrigins.clear();
    _frameListeners.clear();
    _scheduledBy = null;
    _tickerCallbacks.clear();
  }

  Duration _frameTime = Duration.zero;
  List<FrameRequestOrigin> _frameRequests = const [];

  @override
  void handleBeginFrame(Duration? rawTimeStamp) {
    _frameTime = rawTimeStamp ?? Duration.zero;
    // A ticker schedules the frame and registers its callback; count it once,
    // through the callback, whose origin names where the ticker started.
    final scheduledBy = _scheduledBy;
    _frameRequests = [
      if (scheduledBy != null && !scheduledBy.isTicker) scheduledBy,
      ..._tickerCallbacks,
    ];
    _scheduledBy = null;
    _tickerCallbacks.clear();
    _picturesThisFrame = 0;
    super.handleBeginFrame(rawTimeStamp);
  }

  @override
  void drawFrame() {
    super.drawFrame();
    if (_recording) {
      final frame = DrawnFrame(
        timeStamp: _frameTime,
        requests: _frameRequests,
        picturesRecorded: _picturesThisFrame,
      );
      for (final l in List.of(_frameListeners)) {
        l(frame);
      }
    }
  }
}

/// Wraps a real recorder so the finished picture can be mapped to its ops.
class _RecordingPictureRecorder implements ui.PictureRecorder {
  _RecordingPictureRecorder(this.inner, this._opsByPicture);

  final ui.PictureRecorder inner;
  final Expando<List<RecordedOp>> _opsByPicture;
  final List<RecordedOp> ops = [];

  @override
  bool get isRecording => inner.isRecording;

  @override
  ui.Picture endRecording() {
    final picture = inner.endRecording();
    _opsByPicture[picture] = ops;
    return picture;
  }
}
