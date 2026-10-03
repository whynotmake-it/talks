import 'dart:ui' as ui;
import 'package:flutter/rendering.dart' show Rect;

import '../capture/recorded_op.dart';

/// Model-space ops. All geometry is in ROOT (physical pixel) coordinates —
/// the display list transform stack is pre-multiplied during synthesis, so
/// the replay's `effect_transform` is identity. `ctmScale` preserves the
/// transform basis length for sigma scaling.
sealed class MOp {
  String get debugName;
}

class MSave extends MOp {
  @override
  String get debugName => 'save';
}

class MRestore extends MOp {
  @override
  String get debugName => 'restore';
}

/// Model paint carrying the attributes Impeller's `Paint` decisions need.
class MPaint {
  const MPaint({
    this.alpha = 1.0,
    this.blendMode = ui.BlendMode.srcOver,
    this.imageFilter,
    this.colorFilterAffectsTransparentBlack = false,
    this.hasColorFilter = false,
    this.invertColors = false,
    this.maskBlurSigma = 0,
    this.hasRuntimeShader = false,
  });

  final double alpha;
  final ui.BlendMode blendMode;
  final FilterDesc? imageFilter;
  final bool colorFilterAffectsTransparentBlack;
  final bool hasColorFilter;
  final bool invertColors;
  final double maskBlurSigma;

  /// `usesRuntimeEffect` (dl_builder.h:736) — a fragment-shader saveLayer
  /// paint poisons group-opacity compat.
  final bool hasRuntimeShader;

  /// `Paint::CanApplyOpacityPeephole` — impeller/display_list/paint.h:42.
  bool get canApplyOpacityPeephole =>
      blendMode == ui.BlendMode.srcOver &&
      !invertColors &&
      maskBlurSigma == 0 &&
      imageFilter == null &&
      !hasColorFilter;
}

/// `kLastPipelineBlendMode` — impeller/entity/entity.h:28.
const ui.BlendMode kLastPipelineBlendMode = ui.BlendMode.modulate;

/// `Entity::IsBlendModeDestructive` — impeller/entity/entity.cc:128.
bool isBlendModeDestructive(ui.BlendMode m) => switch (m) {
  ui.BlendMode.clear ||
  ui.BlendMode.src ||
  ui.BlendMode.srcIn ||
  ui.BlendMode.dstIn ||
  ui.BlendMode.srcOut ||
  ui.BlendMode.dstOut ||
  ui.BlendMode.dstATop ||
  ui.BlendMode.xor ||
  ui.BlendMode.modulate => true,
  _ => false,
};

/// Blend mode ordering follows dart:ui `BlendMode`, whose enum order matches
/// `DlBlendMode` (the engine relies on identical ordering).
bool isAdvancedBlend(ui.BlendMode m) => m.index > kLastPipelineBlendMode.index;

class MSaveLayer extends MOp {
  MSaveLayer({
    required this.paint,
    this.bounds,
    this.backdropFilter,
    this.backdropId,
    this.canDistributeOpacity = false,
    this.mayClipContents = false,
    this.debugLabel = 'saveLayer',
    this.ctmScale = const ui.Size(1, 1),
  });

  /// saveLayer paint (dl_dispatcher.cc:313: attribute paint when the caller
  /// supplied attributes, else a default paint).
  final MPaint paint;

  /// Caller-provided bounds in root space; null means "unbounded content"
  /// (flood to coverage limit). See dl_dispatcher.cc:325-328.
  Rect? bounds;

  /// Backdrop filter (DlImageFilter*) for `kSaveLayerBackdrop` ops.
  final FilterDesc? backdropFilter;

  /// `backdrop_id` — set when the layer carries a `BackdropKey` (used by
  /// BackdropGroup). canvas.cc:1810.
  final int? backdropId;

  /// DL `can_distribute_opacity` — `is_group_opacity_compatible()` &&
  /// !content_is_unbounded (dl_builder.cc:723, dl_dispatcher.cc:333).
  /// Mutable: the synthesizer patches it at restore once content bounds and
  /// group compatibility are known (matches when dl_builder sets it).
  bool canDistributeOpacity;

  /// `ContentBoundsPromise::kMayClipContents` — set when caller bounds clip
  /// the content (dl_dispatcher.cc:318). Mutable: patched at restore.
  bool mayClipContents;

  final String debugLabel;

  /// Basis length of the transform the saveLayer was recorded under — scales
  /// filter sigmas into physical pixels (gaussian_blur_filter_contents.cc:106).
  final ui.Size ctmScale;

  @override
  String get debugName => 'saveLayer($debugLabel)';
}

class MClip extends MOp {
  MClip({
    required this.coverage,
    this.isDifference = false,
    this.debugLabel = 'clip',
  });

  /// Clip coverage in root space. Engine clips reduce coverage to the
  /// bounding box of the clip (clip_contents.cc:45).
  final Rect coverage;
  final bool isDifference;
  final String debugLabel;

  @override
  String get debugName => 'clip($debugLabel)';
}

class MDraw extends MOp {
  MDraw({
    required this.name,
    this.blendMode = ui.BlendMode.srcOver,
    this.bounds,
    this.imageFilter,
    this.ctmScale = const ui.Size(1, 1),
  });

  final String name;
  final ui.BlendMode blendMode;

  /// Draw bounds in root space — needed to size draw-level filter passes.
  final Rect? bounds;

  /// Paint-level image filter — spawns RenderToSnapshot subpasses.
  final FilterDesc? imageFilter;

  /// Per-axis basis scale of the draw's effective CTM — scales filter
  /// radii/sigmas.
  final ui.Size ctmScale;

  @override
  String get debugName => name;
}

/// A frame's worth of ops plus the flags the dispatcher needs up front.
class FrameOps {
  FrameOps({
    required this.ops,
    required this.rootHasBackdropFilter,
    required this.maxRootBlendMode,
    required this.screenSize,
  });

  final List<MOp> ops;

  /// `DisplayList::root_has_backdrop_filter` — any backdrop op anywhere
  /// propagates to root (dl_builder.cc:173, 532, 1827).
  final bool rootHasBackdropFilter;

  /// `DisplayList::max_root_blend_mode`.
  final ui.BlendMode maxRootBlendMode;

  /// Render target size in physical pixels.
  final ui.Size screenSize;
}
