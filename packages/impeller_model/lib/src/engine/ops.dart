/// The op stream the canvas port replays: the subset of DisplayList ops
/// that matter for pass decisions.
///
/// All geometry is in ROOT (physical pixel) coordinates. The display list
/// transform stack is pre-multiplied during synthesis, so the replay's
/// `effect_transform` is identity. `ctmScale` preserves the transform basis
/// length for sigma scaling.
library;

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show Rect;

import '../capture/recorded_op.dart';

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

  /// ```engine impeller/display_list/paint.h
  ///   static bool CanApplyOpacityPeephole(const Paint& paint) {
  ///     return paint.blend_mode == BlendMode::kSrcOver &&
  ///            paint.invert_colors == false &&
  ///            !paint.mask_blur_descriptor.has_value() &&
  ///            paint.image_filter == nullptr && paint.color_filter == nullptr;
  /// ```
  bool get canApplyOpacityPeephole =>
      blendMode == ui.BlendMode.srcOver &&
      !invertColors &&
      maskBlurSigma == 0 &&
      imageFilter == null &&
      !hasColorFilter;
}

/// ```engine impeller/entity/entity.h
///   static constexpr BlendMode kLastPipelineBlendMode = BlendMode::kModulate;
/// ```
const ui.BlendMode kLastPipelineBlendMode = ui.BlendMode.modulate;

/// ```engine impeller/entity/entity.cc
/// bool Entity::IsBlendModeDestructive(BlendMode blend_mode) {
///   switch (blend_mode) {
///     case BlendMode::kClear:
///     case BlendMode::kSrc:
///     case BlendMode::kSrcIn:
///     case BlendMode::kDstIn:
///     case BlendMode::kSrcOut:
///     case BlendMode::kDstOut:
///     case BlendMode::kDstATop:
///     case BlendMode::kXor:
///     case BlendMode::kModulate:
///       return true;
/// ```
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
/// `DlBlendMode`: the engine casts the Dart index directly.
///
/// ```engine lib/ui/painting/paint.cc
///     paint.setBlendMode(static_cast<DlBlendMode>(blend_mode));
/// ```
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
  /// (flood to coverage limit).
  Rect? bounds;

  /// Backdrop filter (DlImageFilter*) for `kSaveLayerBackdrop` ops.
  final FilterDesc? backdropFilter;

  /// `backdrop_id`, set when the layer carries a `BackdropKey` (used by
  /// BackdropGroup).
  final int? backdropId;

  /// DL `can_distribute_opacity`: `is_group_opacity_compatible()` &&
  /// !content_is_unbounded.
  /// Mutable: the synthesizer patches it at restore once content bounds and
  /// group compatibility are known (matches when dl_builder sets it).
  bool canDistributeOpacity;

  /// `ContentBoundsPromise::kMayClipContents`, set when caller bounds clip
  /// the content. Mutable: patched at restore.
  bool mayClipContents;

  final String debugLabel;

  /// Basis length of the transform the saveLayer was recorded under; it
  /// scales filter sigmas into physical pixels.
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

  /// Clip coverage in root space: the clip's bounding box.
  final Rect coverage;
  final bool isDifference;
  final String debugLabel;

  @override
  String get debugName => 'clip($debugLabel)';
}

/// Whether a draw with a `MaskFilter.blur` spawns Gaussian blur passes.
///
/// Filled shapes without a shader take the shadow fast path, an analytic
/// blur drawn in the current pass (this is what `BoxShadow` hits):
///
/// ```engine impeller/display_list/canvas.cc
/// bool Canvas::IsShadowBlurDrawOperation(const Paint& paint) {
///   if (paint.style != Paint::Style::kFill) {
///     return false;
///   }
///
///   if (paint.color_source) {
///     return false;
///   }
/// ```
///
/// Rect, oval, rrect, rsuperellipse, circle and path draws check it first.
/// Everything else falls through to `CreateMaskBlur`, a real blur:
///
/// ```engine impeller/display_list/canvas.cc
///     auto filter = paint.mask_blur_descriptor->CreateMaskBlur(
/// ```
bool maskBlurNeedsPasses({
  required String opName,
  required bool isFill,
  required bool hasShader,
}) {
  const fastPathOps = {
    'drawRect',
    'drawRRect',
    'drawRSuperellipse',
    'drawOval',
    'drawCircle',
    'drawPath',
  };
  return !(isFill && !hasShader && fastPathOps.contains(opName));
}

class MDraw extends MOp {
  MDraw({
    required this.name,
    this.blendMode = ui.BlendMode.srcOver,
    this.bounds,
    this.imageFilter,
    this.maskBlur,
    this.ctmScale = const ui.Size(1, 1),
    this.cause,
  });

  /// A mask blur that spawns blur passes, i.e. one that misses the shadow
  /// fast path (see [maskBlurNeedsPasses]). Null when there is none.
  final FilterDesc? maskBlur;

  /// Widget/layer that recorded the draw, when known.
  final String? cause;

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

  /// `DisplayList::root_has_backdrop_filter`.
  final bool rootHasBackdropFilter;

  /// `DisplayList::max_root_blend_mode`.
  final ui.BlendMode maxRootBlendMode;

  /// Render target size in physical pixels.
  final ui.Size screenSize;
}
