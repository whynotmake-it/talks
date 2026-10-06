/// Port of `RenderToTarget` (impeller/display_list/dl_dispatcher.cc): a
/// first pass collects backdrop data, then the op stream is replayed
/// through the canvas.
library;

import 'canvas.dart';
import 'capabilities.dart';
import 'ops.dart';

/// Replays a synthesized frame op stream through the Canvas port and returns
/// the estimated pass timeline.
///
/// ```engine impeller/display_list/dl_dispatcher.cc
///   FirstPassDispatcher collector(context, impeller::Matrix(), cull_rect);
///   display_list->Dispatch(collector, cull_rect);
/// ```
PassTimeline replayFrame(FrameOps frame, CapabilityProfile profile) {
  final canvas = ImpellerCanvasReplay(
    profile: profile,
    screenSize: frame.screenSize,
    rootHasBackdropFilter: frame.rootHasBackdropFilter,
    maxRootBlendMode: frame.maxRootBlendMode,
  );

  // Pre-pass: every backdrop saveLayer is counted up front, keyed ones also
  // register per-key data.
  for (final op in frame.ops) {
    if (op is MSaveLayer && op.backdropFilter != null) {
      canvas.registerBackdrop(op.backdropId, op.backdropFilter!);
    }
  }

  for (final op in frame.ops) {
    switch (op) {
      case MSave():
        canvas.save();
      case MRestore():
        canvas.restore();
      case MSaveLayer():
        canvas.saveLayer(
          paint: op.paint,
          bounds: op.bounds,
          backdropFilter: op.backdropFilter,
          backdropId: op.backdropId,
          canDistributeOpacity: op.canDistributeOpacity,
          mayClipContents: op.mayClipContents,
          debugLabel: op.debugLabel,
          ctmScale: op.ctmScale,
        );
      case MClip():
        canvas.clip(op.coverage, isDifference: op.isDifference);
      case MDraw():
        canvas.draw(
          blendMode: op.blendMode,
          bounds: op.bounds,
          imageFilter: op.imageFilter,
          maskBlur: op.maskBlur,
          ctmScale: op.ctmScale,
          name: op.cause ?? op.name,
        );
    }
  }

  return canvas.endReplay();
}
