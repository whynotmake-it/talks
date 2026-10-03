import 'canvas_replay.dart';
import 'capabilities.dart';
import 'ops.dart';

/// Replays a synthesized frame op stream through the Canvas port and returns
/// the estimated pass timeline.
PassTimeline replayFrame(FrameOps frame, CapabilityProfile profile) {
  final canvas = ImpellerCanvasReplay(
    profile: profile,
    screenSize: frame.screenSize,
    rootHasBackdropFilter: frame.rootHasBackdropFilter,
    maxRootBlendMode: frame.maxRootBlendMode,
  );

  // Pre-pass: the dispatcher counts EVERY backdrop saveLayer up front
  // (dl_dispatcher.cc:1002) and additionally registers backdrop_ids
  // (:1003-1016).
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
          ctmScale: op.ctmScale,
        );
    }
  }

  return canvas.endReplay();
}
