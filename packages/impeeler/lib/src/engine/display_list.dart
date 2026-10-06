/// Turns a captured layer tree plus recorded picture ops into the op stream
/// Impeller's canvas receives: a port of the `flow::Layer::Paint` methods
/// (flow/layers/*.cc) and `DisplayListBuilder` bookkeeping
/// (display_list/dl_builder.cc) that decide saveLayers, opacity peepholes
/// and bounds.
library;

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart' show Rect;
import 'package:vector_math/vector_math_64.dart';

import '../capture/layer_walk.dart';
import '../capture/recorded_op.dart';
import 'ops.dart';

/// Running bounds plus a conservative overlap flag: true when a new rect
/// intersects the accumulated bounds of all previous rects.
///
/// ```engine display_list/utils/dl_accumulation_rect.cc
///   if (r.GetLeft() < max_x_ && r.GetRight() > min_x_ &&  //
///       r.GetTop() < max_y_ && r.GetBottom() > min_y_) {
///     record_overlapping_bounds();
///   }
/// ```
class AccumulationRect {
  double _l = double.infinity, _t = double.infinity;
  double _r = double.negativeInfinity, _b = double.negativeInfinity;
  bool overlapDetected = false;

  void accumulate(Rect? rect) {
    if (rect == null || rect.isEmpty || !rect.isFinite) {
      return;
    }
    if (rect.left < _r &&
        rect.right > _l &&
        rect.top < _b &&
        rect.bottom > _t) {
      overlapDetected = true;
    }
    _l = rect.left < _l ? rect.left : _l;
    _t = rect.top < _t ? rect.top : _t;
    _r = rect.right > _r ? rect.right : _r;
    _b = rect.bottom > _b ? rect.bottom : _b;
  }

  Rect? get bounds => isEmpty ? null : Rect.fromLTRB(_l, _t, _r, _b);
  bool get isEmpty => _l >= _r || _t >= _b;

  /// Narrow accumulated bounds to [clip] — the clip restricts coverage but
  /// the overlap flag is preserved from the original rects.
  void clampTo(Rect clip) {
    if (isEmpty) {
      return;
    }
    _l = _l < clip.left ? clip.left : _l;
    _t = _t < clip.top ? clip.top : _t;
    _r = _r > clip.right ? clip.right : _r;
    _b = _b > clip.bottom ? clip.bottom : _b;
  }
}

/// Summary of a synthesized subtree — the flow preroll's equivalent of
/// paint bounds plus the DL builder's per-layer flags.
///
/// Scoping mirrors dl_builder:
///  * `layer_local_accumulator` is per saveLayer scope. A nested saveLayer
///    contributes only its union bounds to the parent:
///
///    ```engine display_list/dl_builder.cc
///      layer_op->rect = content_bounds;
///    ```
///    ```engine display_list/dl_builder.cc
///      TransferLayerBounds(content_bounds);
///    ```
///  * A `drawDisplayList` op contributes one bounds rect and propagates
///    the child list's group-opacity flag as an incompatible-op flag:
///
///    ```engine display_list/dl_builder.cc
///      UpdateLayerOpacityCompatibility(display_list->can_apply_group_opacity());
///    ```
///  * Transparent layers (clip/transform/offset containers) do not create a
///    scope: their contents accumulate flat into the parent.
class SubtreeSummary {
  /// This scope's `layer_local_accumulator`: one rect per op contributed.
  ///
  /// ```engine display_list/dl_builder.h
  ///     bool is_group_opacity_compatible() const {
  ///       return !opacity_incompatible_op_detected &&
  ///              !layer_local_accumulator.overlap_detected();
  ///     }
  /// ```
  final accumulator = AccumulationRect();

  /// Bounds per op this subtree contributes to the PARENT scope: a saveLayer
  /// or picture subtree contributes one rect, an opacity scope one rect per
  /// drawable child, and transparent containers forward their children's.
  final opRects = <Rect>[];

  bool unbounded = false;
  bool hasBackdrop = false;

  /// This scope's `!opacity_incompatible_op_detected`. Does not include
  /// nested-scoped content.
  bool opacityCompatible = true;

  /// `renderable_state_flags & kCallerCanApplyOpacity` — whether this
  /// subtree can accept an outstanding opacity on behalf of itself.
  /// Leaf platform views cannot (platform_view_layer never opts in);
  /// pictures, textures and saveLayer emitters can.
  bool acceptsOpacity = true;

  /// kCallerCanApplyOpacity on a saveLayer-emitting subtree — saveLayer
  /// layers advertise kSaveLayerRenderFlags which includes it.
  bool acceptsColorFilter = false;

  /// The aggregate flag: AND of children, zeroed when children overlap.
  ///
  /// ```engine flow/layers/container_layer.cc
  ///     all_renderable_state_flags &= context->renderable_state_flags;
  ///     if (child_paint_bounds->IntersectsWithRect(layer->paint_bounds())) {
  ///       // This will allow inheritance by a linear sequence of non-overlapping
  ///       // children, but will fail with a grid or other arbitrary 2D layout.
  ///       // See https://github.com/flutter/flutter/issues/93899
  ///       all_renderable_state_flags = 0;
  ///     }
  /// ```
  bool get canAcceptOpacity => acceptsOpacity && !accumulator.overlapDetected;
  bool get canAcceptColorFilter =>
      acceptsColorFilter && !accumulator.overlapDetected;

  /// Max blend mode of ops this subtree applies against the PARENT pass.
  /// For a saveLayer subtree this is the saveLayer's own composite blend.
  /// Blends inside the subpass composite against the subpass texture and
  /// do not reach `max_root_blend_mode`.
  ui.BlendMode opBlendMode = ui.BlendMode.srcOver;

  /// Max blend mode of ops in THIS scope; at the root it is
  /// `max_root_blend_mode`, which decides `RequiresReadbackForBlends`.
  ///
  /// ```engine display_list/dl_builder.h
  ///     DlBlendMode max_blend_mode = DlBlendMode::kClear;
  /// ```
  ui.BlendMode maxBlendMode = ui.BlendMode.clear;

  Rect? get bounds => accumulator.bounds;

  bool get isGroupOpacityCompatible =>
      opacityCompatible && !accumulator.overlapDetected;

  /// Intersect this subtree's contributed op bounds with [clip]: a clip
  /// layer's paint bounds are its children's, clipped.
  void clipContribution(Rect clip) {
    for (var i = 0; i < opRects.length; i++) {
      opRects[i] = opRects[i].intersect(clip);
    }
    opRects.removeWhere((r) => r.isEmpty);
    accumulator.clampTo(clip);
  }

  void _accumulateContribution(SubtreeSummary child) {
    for (final r in child.opRects) {
      accumulator.accumulate(r);
    }
    opRects.addAll(child.opRects);
  }

  /// Merge a child that ran in the SAME builder scope (transparent
  /// container): ops accumulate leaf-level, internal incompatibility flags
  /// and blend modes propagate.
  void absorbFlat(SubtreeSummary child) {
    unbounded = unbounded || child.unbounded;
    hasBackdrop = hasBackdrop || child.hasBackdrop;
    acceptsOpacity = acceptsOpacity && child.acceptsOpacity;
    opacityCompatible = opacityCompatible && child.opacityCompatible;
    // Same scope: the child's op-level blends ARE this scope's blends.
    if (child.opBlendMode.index > maxBlendMode.index) {
      maxBlendMode = child.opBlendMode;
    }
    if (child.opBlendMode.index > opBlendMode.index) {
      opBlendMode = child.opBlendMode;
    }
    accumulator.overlapDetected =
        accumulator.overlapDetected || child.accumulator.overlapDetected;
    _accumulateContribution(child);
  }

  /// Merge a child that was a layer-scope boundary (saveLayer op, or a
  /// picture-as-drawDisplayList op): contributes its op bounds plus the
  /// op's own compatibility and composite blend. Internal overlap does not
  /// propagate, and internal blends composite inside the child's subpass.
  void absorbScoped(SubtreeSummary child, {required bool opCompatible}) {
    unbounded = unbounded || child.unbounded;
    hasBackdrop = hasBackdrop || child.hasBackdrop;
    acceptsOpacity = acceptsOpacity && child.acceptsOpacity;
    acceptsColorFilter = acceptsColorFilter && child.acceptsColorFilter;
    opacityCompatible = opacityCompatible && opCompatible;
    if (child.opBlendMode.index > maxBlendMode.index) {
      maxBlendMode = child.opBlendMode;
    }
    if (child.opBlendMode.index > opBlendMode.index) {
      opBlendMode = child.opBlendMode;
    }
    _accumulateContribution(child);
  }
}

/// Convert a [CapturedLayer] tree (whose picture layers carry their recorded
/// ops) into the model op stream.
class LayerSynthesizer {
  /// `BackdropKey` instance → synthetic backdrop_id. BackdropKey uses
  /// default identity equality so the object keys the map directly.
  final Map<Object, int> _backdropIds = {};

  FrameOps synthesize(CapturedLayer root, ui.Size screenSize) {
    final ops = <MOp>[];
    final summary = _emitLayer(root, Matrix4.identity(), ops);
    return FrameOps(
      ops: ops,
      rootHasBackdropFilter: summary.hasBackdrop,
      maxRootBlendMode: summary.maxBlendMode,
      screenSize: screenSize,
    );
  }

  static Rect _transformRect(Matrix4 m, Rect r) {
    final p0 = m.transform3(Vector3(r.left, r.top, 0));
    final p1 = m.transform3(Vector3(r.right, r.top, 0));
    final p2 = m.transform3(Vector3(r.left, r.bottom, 0));
    final p3 = m.transform3(Vector3(r.right, r.bottom, 0));
    double loX = p0.x, hiX = p0.x, loY = p0.y, hiY = p0.y;
    for (final p in [p1, p2, p3]) {
      loX = p.x < loX ? p.x : loX;
      hiX = p.x > hiX ? p.x : hiX;
      loY = p.y < loY ? p.y : loY;
      hiY = p.y > hiY ? p.y : hiY;
    }
    return Rect.fromLTRB(loX, loY, hiX, hiY);
  }

  /// Per-axis basis-vector length of [m] — x and y columns transformed.
  static ui.Size _basisScaleXY(Matrix4 m) {
    final x = m.transform3(Vector3(1, 0, 0)) - m.transform3(Vector3.zero());
    final y = m.transform3(Vector3(0, 1, 0)) - m.transform3(Vector3.zero());
    return ui.Size(x.length, y.length);
  }

  int _backdropIdFor(Object key) =>
      _backdropIds.putIfAbsent(key, () => _backdropIds.length);

  /// Container layers whose children draw into the SAME builder scope
  /// (no saveLayer op): bounds and flags merge leaf-level.
  /// [AnnotatedRegionLayer] is generic — its runtimeType string carries a
  /// type argument — matched by prefix.
  static const _transparentTypes = {
    'OffsetLayer',
    'TransformLayer',
    'ClipRectLayer',
    'ClipRRectLayer',
    'ClipRSuperellipseLayer',
    'ClipPathLayer',
    'LeaderLayer',
    'FollowerLayer',
    'PerformanceOverlayLayer',
    // AnnotatedRegionLayer<T> matched by prefix below.
  };

  static bool _isTransparentType(String type) =>
      _transparentTypes.contains(type) ||
      type.startsWith('AnnotatedRegionLayer');

  /// Emit ops for a layer subtree; returns its summary.
  ///
  /// [cullRect] is the enclosing clip coverage in root space; backdrop
  /// filter layers union it into their paint bounds.
  ///
  /// [inheritedAlpha] is the `LayerStateStack` outstanding opacity: it
  /// multiplies into saveLayer paints (one saveLayer, combined alpha) and
  /// wraps each picture in `saveLayer(alpha)`:
  ///
  /// ```engine impeller/display_list/dl_dispatcher.cc
  ///   if (opacity < SK_Scalar1) {
  ///     Paint save_paint;
  ///     save_paint.color = Color(0, 0, 0, opacity);
  ///     GetCanvas().SaveLayer(save_paint, display_list->GetBounds(), nullptr,
  ///                           ContentBoundsPromise::kContainsContents,
  ///                           display_list->total_depth(),
  ///                           display_list->can_apply_group_opacity());
  /// ```
  SubtreeSummary _emitLayer(
    CapturedLayer node,
    Matrix4 ctm,
    List<MOp> out, {
    double inheritedAlpha = 1.0,
    Rect? cullRect,
    // LayerStateStack: outstanding color/image filters merge into a
    // saveLayer-emitting child's paint (kSaveLayerRenderFlags).
    bool inheritedColorFilter = false,
    bool inheritedColorFilterMTB = false,
    FilterDesc? inheritedImageFilter,
  }) {
    // Compose local transform: OffsetLayer.offset, then
    // TransformLayer.transform.
    //
    // ```engine flow/layers/transform_layer.cc
    //   auto mutator = context.state_stack.save();
    //   mutator.transform(transform_);
    // ```
    final nodeCtm = ctm.clone()..translate(node.offset.dx, node.offset.dy);
    final nodeTransform = node.transform;
    if (nodeTransform != null) {
      nodeCtm.multiply(nodeTransform);
    }

    final summary = SubtreeSummary();

    switch (node.type) {
      case 'ImageFilterLayer' when node.filter == null:
        // A filter the engine dropped (e.g. a blur with sigma 0) paints the
        // children unchanged, with the outstanding attributes.
        //
        // ```engine flow/layers/layer_state_stack.cc
        //   if (filter) {
        //     layer_state_stack_->push_image_filter(bounds, filter);
        //   }
        // ```
        for (final c in node.children) {
          _absorbChild(
            summary,
            c,
            _emitLayer(
              c,
              nodeCtm,
              out,
              inheritedAlpha: inheritedAlpha,
              cullRect: cullRect,
              inheritedColorFilter: inheritedColorFilter,
              inheritedColorFilterMTB: inheritedColorFilterMTB,
              inheritedImageFilter: inheritedImageFilter,
            ),
          );
        }
        return summary;

      case 'OpacityLayer':
        if (node.alpha == 255) {
          // ```engine flow/layers/layer_state_stack.cc
          // void MutatorContext::applyOpacity(const DlRect& bounds, DlScalar opacity) {
          //   if (opacity < SK_Scalar1) {
          // ```
          for (final c in node.children) {
            _absorbChild(
              summary,
              c,
              _emitLayer(
                c,
                nodeCtm,
                out,
                inheritedAlpha: inheritedAlpha,
                cullRect: cullRect,
              ),
            );
          }
          return summary;
        }
        // Opacity distributes per child only when every child opts in to
        // kCallerCanApplyOpacity and no child's paint bounds intersect the
        // union of preceding children (see [SubtreeSummary.canAcceptOpacity]).
        // Otherwise one saveLayer(alpha) wraps the whole group:
        //
        // ```engine flow/layers/opacity_layer.cc
        //   set_children_can_accept_opacity((context->renderable_state_flags &
        //                                    LayerStateStack::kCallerCanApplyOpacity) !=
        //                                   0);
        // ```
        final eff = (node.alpha / 255.0) * inheritedAlpha;
        final childSummaries = <SubtreeSummary>[];
        final childOps = <List<MOp>>[];
        var groupRequired = false;
        final union = AccumulationRect();
        for (final c in node.children) {
          final scratch = <MOp>[];
          final cs = _emitLayer(c, nodeCtm, scratch, cullRect: cullRect);
          childSummaries.add(cs);
          childOps.add(scratch);
          // canAcceptOpacity includes the internal-overlap flag: children
          // that self-overlap inside a transparent container zero the
          // aggregate renderable flags.
          if (!cs.canAcceptOpacity) {
            groupRequired = true;
          }
          final cb = cs.bounds;
          if (cb != null &&
              union.bounds != null &&
              cb.overlaps(union.bounds!)) {
            groupRequired = true;
          }
          union.accumulate(cb);
        }

        if (groupRequired) {
          // One saveLayer(alpha) around the whole subtree (PaintChildren
          // inside a single outstanding-opacity saveLayer).
          final merged = SubtreeSummary();
          for (var i = 0; i < childSummaries.length; i++) {
            final c = node.children[i];
            if (_isTransparentType(c.type)) {
              merged.absorbFlat(childSummaries[i]);
            } else {
              // Same op-compat evaluation as _absorbChild: pictures pass
              // their group compat, filtered saveLayers poison it.
              merged.absorbScoped(
                childSummaries[i],
                opCompatible: c.type == 'PictureLayer'
                    ? childSummaries[i].isGroupOpacityCompatible
                    : _opCompatibleFor(c.type, c.blendMode),
              );
            }
          }
          out.add(
            MSaveLayer(
              paint: MPaint(alpha: eff),
              bounds: union.bounds,
              canDistributeOpacity:
                  merged.isGroupOpacityCompatible && !merged.unbounded,
              debugLabel: node.creator ?? 'Opacity',
              ctmScale: _basisScaleXY(nodeCtm),
            ),
          );
          for (final ops in childOps) {
            out.addAll(ops);
          }
          out.add(MRestore());
          final s = _scopedContribution(
            merged,
            compositeBlend: ui.BlendMode.srcOver,
          );
          return s;
        }

        // Distribute: re-emit each child with the alpha applied — pictures
        // get saveLayer(alpha) wraps, saveLayer children get it in their
        // paint, transparent containers pass it through.
        for (var i = 0; i < node.children.length; i++) {
          final c = node.children[i];
          final cs = _emitLayer(
            c,
            nodeCtm,
            out,
            inheritedAlpha: eff,
            cullRect: cullRect,
          );
          if (_isTransparentType(c.type)) {
            summary.absorbFlat(cs);
          } else {
            // The child is wrapped in saveLayer(alpha) (pictures) or carries
            // the opacity in its own saveLayer paint — either way the op
            // emitted into the parent scope is an opacity-compatible
            // saveLayer, UNLESS it is a filtered saveLayer (backdrop/image/
            // color/shader mask) which poisons the parent group check.
            summary.absorbScoped(
              cs,
              opCompatible: _opCompatibleFor(c.type, c.blendMode),
            );
          }
        }
        return summary;

      case 'BackdropFilterLayer':
        final children = <MOp>[];
        final childSummary = _emitChildren(
          node,
          nodeCtm,
          children,
          cullRect: cullRect,
        );
        // paint_bounds = children ∪ local cull rect. It feeds the parent's
        // overlap check even though the coverage floods anyway.
        //
        // ```engine flow/layers/backdrop_filter_layer.cc
        //   child_paint_bounds =
        //       child_paint_bounds.Union(context->state_stack.local_cull_rect());
        // ```
        final bounds = childSummary.bounds == null
            ? cullRect
            : (cullRect == null
                  ? childSummary.bounds
                  : childSummary.bounds!.expandToInclude(cullRect));
        out.add(
          MSaveLayer(
            paint: MPaint(
              alpha: inheritedAlpha,
              blendMode: node.blendMode ?? ui.BlendMode.srcOver,
              hasColorFilter: inheritedColorFilter,
              colorFilterAffectsTransparentBlack: inheritedColorFilterMTB,
              imageFilter: inheritedImageFilter,
            ),
            bounds: bounds,
            backdropFilter: node.filter,
            backdropId: node.backdropKeyIdentity == null
                ? null
                : _backdropIdFor(node.backdropKeyIdentity!),
            // ```engine display_list/dl_builder.cc
            //   // A backdrop will affect up to the entire surface, bounded by the clip
            //   bool will_be_unbounded = (backdrop != nullptr);
            // ```
            //
            // Without a filter (the engine dropped a no-op blur) the entry
            // is a plain saveLayer, which can take the opacity peephole:
            //
            // ```engine flow/layers/layer_state_stack.cc
            //     stack->delegate_->saveLayer(bounds_, stack->outstanding_, blend_mode_,
            //                                 filter_.get(), backdrop_id_);
            // ```
            canDistributeOpacity:
                node.filter == null &&
                childSummary.isGroupOpacityCompatible &&
                !childSummary.unbounded,
            debugLabel: node.creator ?? 'BackdropFilter',
            ctmScale: _basisScaleXY(nodeCtm),
          ),
        );
        out.addAll(children);
        out.add(MRestore());
        final hasBackdrop = node.filter != null;
        childSummary.hasBackdrop = childSummary.hasBackdrop || hasBackdrop;
        final s = _scopedContribution(
          childSummary,
          compositeBlend: node.blendMode ?? ui.BlendMode.srcOver,
        );
        s.hasBackdrop = s.hasBackdrop || hasBackdrop;
        // The op's contributed bounds are paint_bounds (children ∪ cull
        // rect): accumulate, not clamp, so the cull union lands in the
        // parent's op-level overlap check.
        if (bounds != null) {
          s.accumulator.accumulate(bounds);
          s.opRects
            ..clear()
            ..add(bounds);
        }
        return s;

      case 'ImageFilterLayer':
        // An outstanding image filter folds into an accepting child's
        // saveLayer paint (kSaveLayerRenderFlags). Only wrap a group
        // saveLayer when a child can't take it or children overlap.
        //
        // ```engine flow/layers/layer_state_stack.cc
        // void MutatorContext::applyImageFilter(
        // ```
        final ifPass = _filterPass(node, nodeCtm, cullRect);
        if (ifPass.accepting) {
          for (final c in node.children) {
            _absorbChild(
              summary,
              c,
              _emitLayer(
                c,
                nodeCtm,
                out,
                inheritedAlpha: inheritedAlpha,
                cullRect: cullRect,
                inheritedColorFilter: inheritedColorFilter,
                inheritedColorFilterMTB: inheritedColorFilterMTB,
                inheritedImageFilter: _composeFilter(
                  inheritedImageFilter,
                  node.filter,
                ),
              ),
            );
          }
          return summary;
        }
        out.add(
          MSaveLayer(
            paint: MPaint(
              alpha: inheritedAlpha,
              imageFilter: _composeFilter(inheritedImageFilter, node.filter),
              hasColorFilter: inheritedColorFilter,
              colorFilterAffectsTransparentBlack: inheritedColorFilterMTB,
            ),
            bounds: ifPass.union.bounds,
            debugLabel: node.creator ?? 'ImageFiltered',
            ctmScale: _basisScaleXY(nodeCtm),
          ),
        );
        for (final ops in ifPass.childOps) {
          out.addAll(ops);
        }
        out.add(MRestore());
        return _scopedContribution(
          ifPass.merged,
          compositeBlend: ui.BlendMode.srcOver,
        );

      case 'ColorFilterLayer':
        // kCallerCanApplyColorFilter: a saveLayer child absorbs the filter
        // into its paint; pictures/platform views can't → group wrap.
        final cfPass = _filterPass(node, nodeCtm, cullRect);
        if (cfPass.accepting) {
          for (final c in node.children) {
            _absorbChild(
              summary,
              c,
              _emitLayer(
                c,
                nodeCtm,
                out,
                inheritedAlpha: inheritedAlpha,
                cullRect: cullRect,
                inheritedColorFilter: true,
                inheritedColorFilterMTB:
                    inheritedColorFilterMTB ||
                    node.colorFilterAffectsTransparentBlack,
                inheritedImageFilter: inheritedImageFilter,
              ),
            );
          }
          return summary;
        }
        out.add(
          MSaveLayer(
            paint: MPaint(
              alpha: inheritedAlpha,
              hasColorFilter: true,
              // The layer's own colorFilter decides; a luminance matrix
              // stays tight.
              colorFilterAffectsTransparentBlack:
                  node.colorFilterAffectsTransparentBlack ||
                  inheritedColorFilterMTB,
              imageFilter: inheritedImageFilter,
            ),
            bounds: cfPass.union.bounds,
            debugLabel: node.creator ?? 'ColorFiltered',
            ctmScale: _basisScaleXY(nodeCtm),
          ),
        );
        for (final ops in cfPass.childOps) {
          out.addAll(ops);
        }
        out.add(MRestore());
        return _scopedContribution(
          cfPass.merged,
          compositeBlend: ui.BlendMode.srcOver,
        );

      case 'ShaderMaskLayer':
        // saveLayer(paint_bounds) + children + a rect drawn with the shader
        // and the mask blend mode.
        //
        // ```engine flow/layers/shader_mask_layer.cc
        //   mutator.saveLayer(paint_bounds());
        //
        //   PaintChildren(context);
        //
        //   DlPaint dl_paint;
        //   dl_paint.setBlendMode(blend_mode_);
        // ```
        final children = <MOp>[];
        final childSummary = _emitChildren(
          node,
          nodeCtm,
          children,
          cullRect: cullRect,
        );
        out.add(
          MSaveLayer(
            paint: MPaint(
              alpha: inheritedAlpha,
              hasColorFilter: inheritedColorFilter,
              colorFilterAffectsTransparentBlack: inheritedColorFilterMTB,
              imageFilter: inheritedImageFilter,
            ),
            // paint_bounds are the children's; maskRect only places the
            // shader rect.
            bounds: childSummary.bounds,
            debugLabel: node.creator ?? 'ShaderMask',
            ctmScale: _basisScaleXY(nodeCtm),
          ),
        );
        out.addAll(children);
        out.add(
          MDraw(
            name: 'ShaderMask drawPaint',
            blendMode: node.blendMode ?? ui.BlendMode.modulate,
          ),
        );
        out.add(MRestore());
        return _scopedContribution(
          childSummary,
          compositeBlend: ui.BlendMode.srcOver,
        );

      case 'ClipRectLayer':
      case 'ClipRRectLayer':
      case 'ClipRSuperellipseLayer':
      case 'ClipPathLayer':
        final clip = node.clipBounds == null
            ? null
            : _transformRect(nodeCtm, node.clipBounds!);
        if (node.clipBehaviorName == 'antiAliasWithSaveLayer') {
          // ApplyClip, then saveLayer(paint_bounds):
          //
          // ```engine flow/layers/clip_shape_layer.h
          //   bool UsesSaveLayer() const {
          //     return clip_behavior_ == Clip::kAntiAliasWithSaveLayer;
          //   }
          // ```
          // ```engine flow/layers/clip_shape_layer.h
          //     mutator.saveLayer(paint_bounds());
          //     PaintChildren(context);
          // ```
          out.add(MSave());
          if (clip != null) {
            out.add(MClip(coverage: clip, debugLabel: node.type));
          }
          // The saveLayer op is emitted before the clip's children in the
          // real stream; mark the insertion point, emit children into out.
          final insertAt = out.length;
          final nextCull = clip == null || cullRect == null
              ? (clip ?? cullRect)
              : clip.intersect(cullRect);
          final childSummary = _emitChildren(
            node,
            nodeCtm,
            out,
            cullRect: nextCull,
          );
          final bounds = childSummary.bounds;
          // paint_bounds = children ∩ clip; empty paint bounds → the layer
          // is culled entirely, no saveLayer emitted — and NO extra
          // MRestore (the stream must stay balanced).
          if (bounds != null) {
            final clipped = clip == null ? bounds : bounds.intersect(clip);
            out.insert(
              insertAt,
              MSaveLayer(
                paint: MPaint(alpha: inheritedAlpha),
                bounds: clipped,
                // paint_bounds hold the clipped content, so the saveLayer
                // peepholes when the content is group-compatible:
                //
                // ```engine flow/layers/clip_shape_layer.h
                //     set_paint_bounds(
                //         child_paint_bounds.IntersectionOrEmpty(clip_shape_bounds()));
                // ```
                canDistributeOpacity:
                    childSummary.isGroupOpacityCompatible &&
                    !childSummary.unbounded,
                debugLabel:
                    '${node.creator ?? node.type} '
                    '(Clip.antiAliasWithSaveLayer)',
                ctmScale: _basisScaleXY(nodeCtm),
              ),
            );
            out.add(MRestore()); // close the saveLayer
          }
          out.add(MRestore()); // close the save
          return _scopedContribution(
            childSummary,
            compositeBlend: ui.BlendMode.srcOver,
          );
        }
        out.add(MSave());
        if (clip != null) {
          out.add(MClip(coverage: clip, debugLabel: node.type));
        }
        final nextCull = clip == null || cullRect == null
            ? (clip ?? cullRect)
            : clip.intersect(cullRect);
        final s = _emitChildren(
          node,
          nodeCtm,
          out,
          inheritedAlpha: inheritedAlpha,
          cullRect: nextCull,
        );
        out.add(MRestore());
        summary.absorbFlat(s);
        if (clip != null) {
          summary.clipContribution(clip);
        }
        return summary;

      case 'PictureLayer':
        final ops = node.pictureOps ?? const <RecordedOp>[];
        if (inheritedAlpha < 1.0) {
          // drawDisplayList with opacity: saveLayer(alpha) around the whole
          // picture (see [_emitLayer]), can_distribute =
          // can_apply_group_opacity, with no content_is_unbounded gate.
          final children = <MOp>[];
          final picSummary = _emitPicture(
            ops,
            nodeCtm,
            children,
            canvasBounds: node.canvasBounds == null
                ? null
                : _transformRect(nodeCtm, node.canvasBounds!),
            creator: node.creator,
          );
          out.add(
            MSaveLayer(
              paint: MPaint(alpha: inheritedAlpha),
              bounds: picSummary.bounds,
              canDistributeOpacity: picSummary.isGroupOpacityCompatible,
              debugLabel: 'opacity on ${node.creator ?? 'a picture'}',
              ctmScale: _basisScaleXY(nodeCtm),
            ),
          );
          out.addAll(children);
          out.add(MRestore());
          // The saveLayer(alpha) op composites srcOver in the parent pass.
          picSummary.opBlendMode = ui.BlendMode.srcOver;
          return picSummary;
        }
        final picSummary = _emitPicture(
          ops,
          nodeCtm,
          out,
          canvasBounds: node.canvasBounds == null
              ? null
              : _transformRect(nodeCtm, node.canvasBounds!),
          creator: node.creator,
        );
        // An unwrapped drawDisplayList's ops draw inline in the parent pass:
        // internal blends propagate, and the op contributes one bounds rect.
        picSummary.opBlendMode = picSummary.maxBlendMode;
        return picSummary;

      case 'TextureLayer':
      case 'PlatformViewLayer':
        // Contributes its rect bounds to the parent accumulator: a platform
        // view or texture overlapping siblings must still poison a group
        // opacity check (it's an opacity-compatible draw op).
        out.add(MDraw(name: node.type));
        // PlatformViewLayer.rect is already in global space; TextureLayer.rect
        // is layer-local.
        //
        // ```framework flutter/lib/src/rendering/layer.dart
        //   /// Bounding rectangle of this layer in the global coordinate space.
        //   final Rect rect;
        // ```
        final r = node.rect == null
            ? null
            : (node.type == 'PlatformViewLayer'
                  ? node.rect!
                  : _transformRect(nodeCtm, node.rect!));
        if (r != null) {
          summary.accumulator.accumulate(r);
          summary.opRects.add(r);
        }
        // Platform views can't apply outstanding opacity: that forces a group
        // saveLayer under Opacity (they never set renderable_state_flags).
        // Pictures advertise opacity only, never color/image filters:
        //
        // ```engine flow/layers/display_list_layer.cc
        //   if (disp_list->can_apply_group_opacity()) {
        //     context->renderable_state_flags = LayerStateStack::kCallerCanApplyOpacity;
        //   }
        // ```
        summary.acceptsOpacity = node.type != 'PlatformViewLayer';
        summary.acceptsColorFilter =
            node.type != 'TextureLayer' && node.type != 'PlatformViewLayer';
        return summary;

      default:
        // Container layers without paint effects: emit children inline.
        for (final c in node.children) {
          _absorbChild(
            summary,
            c,
            _emitLayer(
              c,
              nodeCtm,
              out,
              inheritedAlpha: inheritedAlpha,
              cullRect: cullRect,
            ),
          );
        }
        return summary;
    }
  }

  /// Build a saveLayer-emitting node's contribution-to-parent summary: the
  /// subtree emits ONE op (the saveLayer draw into the parent pass)
  /// contributing [inner] bounds composited with [compositeBlend]. Internal
  /// blends/overlaps stay scoped to the subpass.
  SubtreeSummary _scopedContribution(
    SubtreeSummary inner, {
    required ui.BlendMode compositeBlend,
  }) {
    final s = SubtreeSummary()
      ..acceptsColorFilter = true
      ..unbounded = inner.unbounded
      // contains_backdrop_filter is copied into the saveLayer op's options
      // but never propagates back to the parent scope:
      //
      // ```engine display_list/dl_builder.cc
      //   if (current_layer().contains_backdrop_filter) {
      //     layer_op->options = layer_op->options.with_contains_backdrop_filter();
      //   }
      // ```
      ..opBlendMode = compositeBlend;
    final b = inner.bounds;
    if (b != null) {
      s.accumulator.accumulate(b);
      s.opRects.add(b);
    }
    return s;
  }

  /// Merge a child subtree summary into the parent's per-scope state using
  /// the flat-vs-scoped rule: transparent containers merge leaf-level, layer
  /// boundaries contribute bounds + op compatibility only.
  void _absorbChild(
    SubtreeSummary summary,
    CapturedLayer child,
    SubtreeSummary childSummary,
  ) {
    if (_isTransparentType(child.type)) {
      summary.absorbFlat(childSummary);
    } else if (child.type == 'PictureLayer') {
      // A drawDisplayList op propagates the child list's
      // can_apply_group_opacity: an internally overlapping or incompatible
      // picture poisons the parent group check.
      summary.absorbScoped(
        childSummary,
        opCompatible: childSummary.isGroupOpacityCompatible,
      );
    } else {
      summary.absorbScoped(
        childSummary,
        opCompatible: _opCompatibleFor(child.type, child.blendMode),
      );
    }
  }

  /// Compose an outstanding (outer) filter with a child's own (inner) —
  /// engine merges outstanding filters ahead of the saveLayer's own.
  static FilterDesc? _composeFilter(FilterDesc? outer, FilterDesc? inner) {
    if (outer == null) {
      return inner;
    }
    if (inner == null) {
      return outer;
    }
    return FilterDesc.compose(inner, outer);
  }

  /// Pre-emit a filter layer's children and decide whether the filter can
  /// be folded into their own saveLayers (all accept + no overlap).
  ({
    bool accepting,
    List<SubtreeSummary> summaries,
    List<List<MOp>> childOps,
    SubtreeSummary merged,
    AccumulationRect union,
  })
  _filterPass(
    CapturedLayer node,
    Matrix4 nodeCtm,
    Rect? cullRect,
  ) {
    final summaries = <SubtreeSummary>[];
    final childOps = <List<MOp>>[];
    final union = AccumulationRect();
    var accepting = true;
    for (final c in node.children) {
      final scratch = <MOp>[];
      final cs = _emitLayer(c, nodeCtm, scratch, cullRect: cullRect);
      summaries.add(cs);
      childOps.add(scratch);
      if (!cs.canAcceptColorFilter) {
        accepting = false;
      }
      final cb = cs.bounds;
      if (cb != null && union.bounds != null && cb.overlaps(union.bounds!)) {
        accepting = false;
      }
      union.accumulate(cb);
    }
    final merged = SubtreeSummary();
    for (var i = 0; i < summaries.length; i++) {
      final c = node.children[i];
      if (_isTransparentType(c.type)) {
        merged.absorbFlat(summaries[i]);
      } else {
        merged.absorbScoped(
          summaries[i],
          opCompatible: c.type == 'PictureLayer'
              ? summaries[i].isGroupOpacityCompatible
              : _opCompatibleFor(c.type, c.blendMode),
        );
      }
    }
    return (
      accepting: accepting,
      summaries: summaries,
      childOps: childOps,
      merged: merged,
      union: union,
    );
  }

  /// The opacity compatibility of a layer-as-an-op in the parent's group
  /// check. A saveLayer op poisons the parent only when it renders with
  /// attributes and its paint isn't opacity-compatible or has an image
  /// filter. A backdrop saveLayer with the default srcOver paint has no
  /// attributes, so it is compatible.
  ///
  /// ```engine display_list/dl_builder.cc
  ///   if (options.renders_with_attributes()) {
  ///     // |current_opacity_compatibility_| does not take an ImageFilter into
  ///     // account because an individual primitive with an ImageFilter can apply
  ///     // opacity on top of it. But, if the layer is applying the ImageFilter
  ///     // then it cannot pass the opacity on.
  ///     if (!current_opacity_compatibility_ || filter) {
  ///       UpdateLayerOpacityCompatibility(false);
  ///     }
  ///   }
  /// ```
  bool _opCompatibleFor(String type, [ui.BlendMode? blendMode]) {
    final bm = blendMode ?? ui.BlendMode.srcOver;
    switch (type) {
      case 'BackdropFilterLayer':
        // The saveLayer's paint carries only the layer's blend mode —
        // srcOver → renders_with_attributes = false → compatible op.
        return bm == ui.BlendMode.srcOver;
      case 'ImageFilterLayer':
      case 'ColorFilterLayer':
      case 'ShaderMaskLayer':
        // hasImageFilter / color filter / mask+shader →
        // renders_with_attributes && (incompatible | imageFilter) → poison.
        return false;
      default:
        return true;
    }
  }

  SubtreeSummary _emitChildren(
    CapturedLayer node,
    Matrix4 ctm,
    List<MOp> out, {
    double inheritedAlpha = 1.0,
    Rect? cullRect,
  }) {
    final summary = SubtreeSummary();
    for (final c in node.children) {
      _absorbChild(
        summary,
        c,
        _emitLayer(
          c,
          ctm,
          out,
          inheritedAlpha: inheritedAlpha,
          cullRect: cullRect,
        ),
      );
    }
    return summary;
  }

  /// Emit a recorded picture's ops; runs a save/saveLayer scope stack that
  /// mirrors `dl_builder`'s layer-local accumulator scoping.
  SubtreeSummary _emitPicture(
    List<RecordedOp> ops,
    Matrix4 layerCtm,
    List<MOp> out, {
    Rect? canvasBounds,
    String? creator,
  }) {
    // drawDisplayList runs inside its own save/restore scope:
    //
    // ```engine impeller/display_list/dl_dispatcher.cc
    //     // The display list may alter the clip, which must be restored to the
    //     // current clip at the end of playback.
    //     GetCanvas().Save(display_list->total_depth());
    // ```
    out.add(MSave());
    final summary = SubtreeSummary()..acceptsColorFilter = false;
    final scopes = <_PicScope>[_PicScope(summary)];
    scopes.first
      ..cullBounds = canvasBounds
      ..creator = creator;
    for (final op in ops) {
      _emitRecordedOp(op, layerCtm, scopes, out);
    }
    // Build() auto-restores any save/saveLayer left open in the picture.
    //
    // ```engine display_list/dl_builder.cc
    //   while (save_stack_.size() > 1) {
    //     restore();
    //   }
    // ```
    while (scopes.length > 1) {
      out.add(MRestore());
      _popScope(scopes);
    }
    out.add(MRestore());
    // A picture is one drawDisplayList op to its parent: one bounds rect.
    // Nested saveLayers already added their content bounds to opRects —
    // clear them; only the union is contributed.
    final b = summary.bounds;
    if (b != null) {
      summary.opRects
        ..clear()
        ..add(b);
    }
    return summary;
  }

  /// Emit one recorded canvas op.
  ///
  /// Op geometry is already in PICTURE space at record time
  /// ([RecordedOp.bounds] docs: transformed by the op's own ctm), so the
  /// layer transform is the only thing left to apply — `layerCtm * op.ctm`
  /// would double-apply it. `ctm` is still needed for the sigma/basis scale.
  void _emitRecordedOp(
    RecordedOp op,
    Matrix4 layerCtm,
    List<_PicScope> scopes,
    List<MOp> out,
  ) {
    final ctm = layerCtm.clone()..multiply(op.ctm);
    final opScale = _basisScaleXY(ctm);
    final summary = _currentSummary(scopes);
    Rect? xf(Rect? r) => r == null ? null : _transformRect(layerCtm, r);

    switch (op.name) {
      case 'save':
        out.add(MSave());
        scopes.add(
          _PicScope.plain()
            ..hasValidClip = _currentScope(scopes).hasValidClip
            ..clipBounds = _currentScope(scopes).clipBounds
            ..cullBounds = _currentScope(scopes).cullBounds,
        );
      case 'restore':
        // A restore past the picture root is a no-op in the engine
        // (restoreToCount clamps) — don't emit an unbalanced MRestore.
        if (scopes.length > 1) {
          out.add(MRestore());
          _popScope(scopes);
        }
      case 'restoreToCount':
        // dl semantics: save count == depth; scopes[0] is the picture root
        // (saveCount 1), so pop until scopes.length == n.
        final n = op.restoreToCount ?? 0;
        while (scopes.length > n && scopes.length > 1) {
          out.add(MRestore());
          _popScope(scopes);
        }
      case 'saveLayer':
        // A canvas-level saveLayer inside a picture is a real DL saveLayer.
        final msl = MSaveLayer(
          paint: MPaint(
            alpha: op.saveLayerPaint?.alpha ?? 1.0,
            blendMode: op.saveLayerPaint?.blendMode ?? ui.BlendMode.srcOver,
            imageFilter: op.saveLayerPaint?.imageFilter,
            hasColorFilter: op.saveLayerPaint?.hasColorFilter ?? false,
            colorFilterAffectsTransparentBlack:
                op.saveLayerPaint?.colorFilterMayAffectTransparentBlack ??
                false,
            invertColors: op.saveLayerPaint?.isInvertColors ?? false,
            maskBlurSigma: op.saveLayerPaint?.maskBlurSigma ?? 0,
            hasRuntimeShader: op.saveLayerPaint?.hasRuntimeShader ?? false,
          ),
          bounds: xf(op.saveLayerBounds),
          // canDistributeOpacity / mayClipContents are patched at the
          // matching restore, when content bounds are known.
          canDistributeOpacity: true,
          debugLabel:
              'canvas.saveLayer in ${scopes.first.creator ?? 'a picture'}',
          ctmScale: opScale,
        );
        out.add(msl);
        // A saveLayer starts with no valid clip of its own (unbounded
        // content inside it marks it unbounded), while the global clip
        // still bounds what it accumulates:
        //
        // ```engine display_list/dl_builder.h
        //         : is_save_layer(true),
        //           has_valid_clip(false),
        //           global_state(parent_info->global_state),
        //           layer_state(kMaxCullRect),
        // ```
        scopes.add(
          _PicScope.saveLayer(msl)
            ..hasValidClip = false
            ..clipBounds = _currentScope(scopes).clipBounds
            ..cullBounds = _currentScope(scopes).cullBounds,
        );
      case 'clipRect':
      case 'clipRRect':
      case 'clipRSuperellipse':
      case 'clipPath':
        if (op.clipRect != null) {
          // has_valid_clip is set by both clip ops; only intersect narrows
          // the bounds.
          //
          // ```engine display_list/dl_builder.cc
          //   current_info().has_valid_clip = true;
          //   checkForDeferredSave();
          //   switch (clip_op) {
          //     case DlClipOp::kIntersect:
          //       Push<ClipIntersectRectOp>(0, rect, is_aa);
          // ```
          final clipBounds = xf(op.clipRect)!;
          final scope = _currentScope(scopes);
          scope.hasValidClip = true;
          if (op.clipOpIsIntersect) {
            scope.clipBounds = scope.clipBounds == null
                ? clipBounds
                : scope.clipBounds!.intersect(clipBounds);
          }
          out.add(
            MClip(
              coverage: clipBounds,
              isDifference: !op.clipOpIsIntersect,
              debugLabel: op.name,
            ),
          );
        }
      case 'drawPicture':
        // Nested pictures recorded through other recorders aren't captured;
        // treat as an opaque draw of unknown extent.
        out.add(MDraw(name: 'drawPicture'));
        summary.unbounded = true;
        summary.opacityCompatible = false;
      case 'drawParagraph':
      case 'drawShadow':
        // ```engine display_list/dl_builder.cc
        //     // There is no way to query if the glyphs of a text blob overlap and
        //     // there are no current guarantees from either Skia or Impeller that
        //     // they will protect overlapping glyphs from the effects of overdraw
        //     // so we must make the conservative assessment that this DL layer is
        //     // not compatible with group opacity inheritance.
        //     UpdateLayerOpacityCompatibility(false);
        // ```
        out.add(MDraw(name: op.name));
        summary.opacityCompatible = false;
        summary.accumulator.accumulate(xf(op.bounds));
      default:
        final paint = op.paint;
        final blendMode =
            op.blendMode ?? paint?.blendMode ?? ui.BlendMode.srcOver;
        final bounds = xf(op.bounds);
        if (op.forcesOverlap) {
          summary.accumulator.overlapDetected = true;
        }
        if (paint != null) {
          // ```engine display_list/dl_builder.h
          //     current_opacity_compatibility_ =             //
          //         current_.getColorFilter() == nullptr &&  //
          //         !current_.isInvertColors() &&            //
          //         !current_.usesRuntimeEffect() &&         //
          //         IsOpacityCompatible(current_.getBlendMode());
          // ```
          final compatible =
              blendMode == ui.BlendMode.srcOver &&
              !paint.isInvertColors &&
              !paint.hasColorFilter &&
              !paint.hasRuntimeShader;
          if (!compatible) {
            summary.opacityCompatible = false;
          }
        }
        if (blendMode.index > summary.maxBlendMode.index) {
          summary.maxBlendMode = blendMode;
        }
        if (op.unbounded) {
          final scope = _currentScope(scopes);
          // AccumulateUnbounded always accumulates the local cull coverage
          // (clip bounds, else the picture's cull rect); is_unbounded is
          // set only when there is no valid clip.
          //
          // ```engine display_list/dl_builder.cc
          // bool DisplayListBuilder::AccumulateUnbounded(const SaveInfo& save) {
          //   if (!save.has_valid_clip) {
          //     save.layer_info->is_unbounded = true;
          //   }
          // ```
          summary.accumulator.accumulate(scope.clipBounds ?? scope.cullBounds);
          if (!scope.hasValidClip) {
            summary.unbounded = true;
          }
        } else {
          summary.accumulator.accumulate(bounds);
        }
        final sigma = paint?.maskBlurSigma ?? 0;
        final maskBlurPasses =
            sigma > 0 &&
            maskBlurNeedsPasses(
              opName: op.name,
              isFill: paint!.style == ui.PaintingStyle.fill,
              hasShader: paint.hasShader,
            );
        out.add(
          MDraw(
            name: op.name,
            blendMode: blendMode,
            bounds: bounds,
            imageFilter: paint?.imageFilter,
            maskBlur: maskBlurPasses
                ? FilterDesc.gaussianBlur(sigma, sigma)
                : null,
            ctmScale: _basisScaleXY(ctm),
          ),
        );
    }
  }

  /// Pop one canvas save state; when it was a saveLayer scope, merge its
  /// union bounds into the parent as ONE rect (TransferLayerBounds) and
  /// patch the deferred saveLayer flags now that content bounds are known.
  void _popScope(List<_PicScope> scopes) {
    if (scopes.length <= 1) {
      return;
    }
    final popped = scopes.removeLast();
    if (!popped.isLayer) {
      return;
    }
    final parent = _currentSummary(scopes);
    final msl = popped.saveLayer!;
    final content = popped.contentSummary!;
    // ```engine display_list/dl_builder.cc
    //   if (current_layer().is_group_opacity_compatible()) {
    //     layer_op->options = layer_op->options.with_can_distribute_opacity();
    //   }
    // ```
    // ```engine impeller/display_list/dl_dispatcher.cc
    //       options.can_distribute_opacity() && !options.content_is_unbounded(),
    // ```
    msl.canDistributeOpacity =
        content.isGroupOpacityCompatible && !content.unbounded;
    // The op rect is always the content bounds, intersected with caller
    // bounds when those clip it (which marks kMayClipContents):
    //
    // ```engine display_list/dl_builder.cc
    //     if (!content_bounds.IsEmpty() && !user_bounds.Contains(content_bounds)) {
    //       layer_op->options = layer_op->options.with_content_is_clipped();
    //       content_bounds = content_bounds.IntersectionOrEmpty(user_bounds);
    //     }
    // ```
    //
    // Unbounded content keeps caller bounds, or floods without them:
    //
    // ```engine impeller/display_list/dl_dispatcher.cc
    //   if (!options.content_is_unbounded() || options.bounds_from_caller()) {
    //     impeller_bounds = bounds;
    //   }
    // ```
    final callerBounds = msl.bounds;
    final cb2 = content.bounds;
    if (content.unbounded) {
      // content_bounds = unbounded → never "contained" by caller bounds.
      msl.mayClipContents = callerBounds != null;
      msl.bounds = callerBounds;
    } else if (cb2 == null) {
      // Empty content: rect = empty → coverage empty → engine skips.
      msl.mayClipContents = false;
      msl.bounds = Rect.zero;
    } else if (callerBounds != null && !_rectContains(callerBounds, cb2)) {
      msl.mayClipContents = true;
      msl.bounds = callerBounds.intersect(cb2);
    } else {
      msl.mayClipContents = false;
      msl.bounds = cb2;
    }
    // A saveLayer op with a filter or incompatible paint poisons the
    // parent's group-opacity check (see [_opCompatibleFor]).
    if (msl.paint.imageFilter != null ||
        msl.paint.hasColorFilter ||
        msl.paint.invertColors ||
        msl.paint.hasRuntimeShader ||
        msl.paint.blendMode != ui.BlendMode.srcOver) {
      parent.opacityCompatible = false;
    }
    // The op contributed to the parent carries the RESOLVED rect
    // (content ∩ caller bounds) — TransferLayerBounds transfers
    // layer_op->rect, not the raw content bounds.
    final cb = msl.bounds;
    if (cb != null) {
      parent.accumulator.accumulate(cb);
      parent.opRects.add(cb);
    }
    // is_unbounded is NOT transferred — a saveLayer with caller bounds
    // over unbounded content is still a bounded op to its parent.
    parent.unbounded =
        parent.unbounded || (msl.bounds == null && content.unbounded);
    // hasBackdrop is deliberately not propagated (see
    // [_scopedContribution]). The saveLayer's own composite blend applies
    // in the parent pass; blends inside it composite against the subpass
    // texture and never reach the parent's max.
    if (msl.paint.blendMode.index > parent.maxBlendMode.index) {
      parent.maxBlendMode = msl.paint.blendMode;
    }
    if (msl.paint.blendMode.index > parent.opBlendMode.index) {
      parent.opBlendMode = msl.paint.blendMode;
    }
  }

  static bool _rectContains(Rect outer, Rect inner) =>
      inner.left >= outer.left &&
      inner.top >= outer.top &&
      inner.right <= outer.right &&
      inner.bottom <= outer.bottom;

  _PicScope _currentScope(List<_PicScope> scopes) => scopes.last;

  /// The scope the next op accumulates into — the nearest enclosing
  /// saveLayer scope, or the picture root.
  SubtreeSummary _currentSummary(List<_PicScope> scopes) {
    for (var i = scopes.length - 1; i >= 0; i--) {
      final s = scopes[i].contentSummary;
      if (s != null) {
        return s;
      }
    }
    return scopes.first.contentSummary!;
  }
}

/// One canvas-save marker while replaying a picture: plain `save`s share
/// the enclosing accumulator; `saveLayer` scopes get their own
/// (dl_builder's layer_local_accumulator scoping).
class _PicScope {
  /// The picture-root scope.
  _PicScope(this.contentSummary) : isLayer = false, saveLayer = null;

  /// A plain `save` — no layer boundary, no own accumulation.
  _PicScope.plain() : contentSummary = null, isLayer = false, saveLayer = null;

  /// A `saveLayer` — own accumulation scope, merged at restore.
  _PicScope.saveLayer(this.saveLayer)
    : isLayer = true,
      contentSummary = SubtreeSummary();

  /// Own accumulation scope; null for plain saves (their ops accumulate
  /// flat into the enclosing scope).
  final SubtreeSummary? contentSummary;
  final bool isLayer;
  final MSaveLayer? saveLayer;

  /// `has_valid_clip`: set by any clip op, inherited by plain saves and
  /// reset by saveLayers (see the `saveLayer` case above).
  bool hasValidClip = false;

  /// The scope's current clip bounds (from intersect clips only — a
  /// difference clip marks validity but doesn't narrow the bound).
  Rect? clipBounds;

  /// The scope's cull coverage (the picture's `canvasBounds`), used when
  /// `hasValidClip` is set by a difference clip with no intersect bound.
  Rect? cullBounds;

  /// Who painted the picture (root scope only), for pass attribution.
  String? creator;
}
