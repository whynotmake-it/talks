/// Estimates the Impeller GPU pass structure of a Flutter frame from a
/// widget test — no device required.
///
/// Pinned to the Flutter 3.47 engine's decision logic; see FEASIBILITY.md
/// for the mirroring-risk discussion.
library impeller_model;

export 'src/capture/binding.dart';
export 'src/capture/layer_walk.dart';
export 'src/capture/recorded_op.dart';
export 'src/capture/recording_canvas.dart';
export 'src/model/canvas_replay.dart';
export 'src/model/capabilities.dart';
export 'src/model/driver.dart';
export 'src/model/filters.dart';
export 'src/model/ops.dart';
export 'src/model/report.dart';
export 'src/model/synthesize.dart';
