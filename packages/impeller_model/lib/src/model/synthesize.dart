import 'dart:ui' as ui;
import 'package:flutter/rendering.dart' show Rect;

import 'package:vector_math/vector_math_64.dart';

import '../capture/layer_walk.dart';
import '../capture/recorded_op.dart';
import 'ops.dart';

/// Port of `AccumulationRect` (dl_accumulation_rect.{h,cc}) — running bounds
/// plus a conservative "overlap" flag: true when a new rect intersects the
/// accumulated bounds of all previous rects.
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
/// IMPORTANT scoping semantics (mirroring dl_builder):
///  * `layer_local_accumulator` is per-saveLayer-scope. A nested saveLayer
///    contributes only its union bounds to the parent (TransferLayerBounds,
///    dl_builder.cc:761).
///  * A `drawDisplayList` op contributes ONE bounds rect, and propagates
///    `can_apply_group_opacity` as an incompatible-op flag
///    (dl_builder.cc:1819) — not via the overlap accumulator.
///  * Transparent layers (clip/transform/offset containers) do not create a
///    scope — their contents accumulate flat into the parent.
class SubtreeSummary {
  /// This scope's `layer_local_accumulator` — accumulates one rect per op
  /// contributed to this scope (dl_builder.h:565).
  final accumulator = AccumulationRect();

  /// Bounds per op this subtree contributes to the PARENT scope: a saveLayer
  /// or picture subtree contributes one rect; an opacity scope contributes
  /// one rect per drawable child (dl_dispatcher.cc:803); transparent
  /// containers forward their children's ops.
  final opRects = <Rect>[];

  bool unbounded = false;
  bool hasBackdrop = false;

  /// This scope's `opacity_incompatible_op_detected`
  /// (dl_builder.h:565). Does NOT include nested-scoped content.
  bool opacityCompatible = true;

  /// `renderable_state_flags & kCallerCanApplyOpacity` — whether this
  /// subtree can accept an outstanding opacity on behalf of itself.
  /// Leaf platform views cannot (platform_view_layer never opts in);
  /// pictures, textures and saveLayer emitters can.
  bool acceptsOpacity = true;

  /// kCallerCanApplyOpacity on a saveLayer-emitting subtree — saveLayer
  /// layers advertise kSaveLayerRenderFlags which includes it.
  bool acceptsColorFilter = false;

  /// The aggregate flag — AND of children, zeroed when children overlap
  /// (container_layer.cc:146-151: a child intersecting the accumulated
  /// union of previous children zeroes all renderable state flags).
  bool get canAcceptOpacity => acceptsOpacity && !accumulator.overlapDetected;
  bool get canAcceptColorFilter =>
      acceptsColorFilter && !accumulator.overlapDetected;

  /// Max blend mode of ops this subtree applies against the PARENT pass.
  /// For a saveLayer subtree this is the composite blend of the saveLayer
  /// itself (`max_blend_mode` on the op — dl_dispatcher.cc:717), NOT blends
  /// executed inside the subpass — those composite against the subpass
  /// texture and do not reach `max_root_blend_mode`.
  ui.BlendMode opBlendMode = ui.BlendMode.srcOver;

  /// Max blend mode of ops in THIS scope — feeds `max_root_blend_mode` at
  /// the frame root (dl_dispatcher.cc:949 `RequiresReadbackForBlends`).
  ui.BlendMode maxBlendMode = ui.BlendMode.clear;

  Rect? get bounds => accumulator.bounds;

  /// `LayerInfo::is_group_opacity_compatible` (dl_builder.h:570).
  bool get isGroupOpacityCompatible =>
      opacityCompatible && !accumulator.overlapDetected;

  /// Intersect this subtree's contributed op bounds with [clip] — clip
  /// contents bounds are clipped before propagating to the parent
  /// (clip_contents.cc:45).
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
  /// op's own compatibility/composite blend — internal overlap does NOT
  /// propagate (TransferLayerBounds, dl_builder.cc:761), and internal blends
  /// composite inside the child's own subpass.
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

/// Convert a [CapturedLayer] tree + recorded picture ops into the model op
/// stream, mimicking `flow::Layer::Paint` methods and `DisplayListBuilder`
/// bookkeeping.
class LayerSynthesizer {
  LayerSynthesizer({required this.pictures});

  /// Recorded picture op streams (from [OpRecorderRegistry]).
  final List<List<RecordedOp>> pictures;

  /// `BackdropKey` instance → synthetic backdrop_id. BackdropKey uses
  /// default identity equality so the object keys the map directly.
  final Map<Object, int> _backdropIds = {};

  /// Node → picture index resolved by content match (canvasBounds
  /// containment), not positional order — `createCanvas` calls arrive in
  /// paint order, which differs from layer-tree order.
  final Map<CapturedLayer, int> _picMatch = {};

  FrameOps synthesize(CapturedLayer root, ui.Size screenSize) {
    _matchPictures(root);
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

  /// Union of a picture's recorded bounds in picture space — ops record
  /// their bounds already transformed by the op's own CTM, so this union
  /// approximates the content footprint that must fit inside the owning
  /// `PictureLayer.canvasBounds` (layer.dart:834).
  static Rect? _pictureUnion(List<RecordedOp> ops) {
    Rect? u;
    for (final op in ops) {
      final r = op.bounds ?? op.clipRect ?? op.saveLayerBounds;
      if (r == null || !r.isFinite || r.isEmpty) {
        continue;
      }
      u = u == null ? r : u.expandToInclude(r);
    }
    return u;
  }

  static bool _fitsInside(Rect inner, Rect outer) =>
      inner.left >= outer.left - 1 &&
      inner.top >= outer.top - 1 &&
      inner.right <= outer.right + 1 &&
      inner.bottom <= outer.bottom + 1;

  void _matchPictures(CapturedLayer root) {
    final layers = <CapturedLayer>[];
    void walk(CapturedLayer n) {
      if (n.type == 'PictureLayer') {
        layers.add(n);
      }
      for (final c in n.children) {
        walk(c);
      }
    }

    walk(root);

    final unions = [for (final p in pictures) _pictureUnion(p)];
    final assigned = <int>{};
    var cursor = 0;
    for (final layer in layers) {
      final cb = layer.canvasBounds;
      int? best;
      var bestSlack = double.infinity;
      for (var i = 0; i < pictures.length; i++) {
        if (assigned.contains(i)) {
          continue;
        }
        final u = unions[i];
        if (cb == null || u == null) {
          continue;
        }
        // Content must fit inside the canvas bounds; prefer the
        // tightest-fitting picture for this layer.
        if (_fitsInside(u, cb)) {
          final slack = cb.width * cb.height - u.width * u.height;
          if (slack < bestSlack) {
            bestSlack = slack;
            best = i;
          }
        }
      }
      // Positional fallback when containment can't disambiguate.
      if (best == null) {
        while (cursor < pictures.length && assigned.contains(cursor)) {
          cursor++;
        }
        best = cursor < pictures.length ? cursor : null;
      }
      if (best != null) {
        assigned.add(best);
        _picMatch[layer] = best;
        layer.pictureIndex = best;
      }
    }
  }

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
  /// [cullRect] is the enclosing clip coverage in root space — backdrop
  /// filter layers union it into paint_bounds (backdrop_filter_layer.cc:52).
  ///
  /// [inheritedAlpha] is the `layer_state_stack` outstanding opacity: it
  /// multiplies into saveLayer paints (one saveLayer, combined alpha) and
  /// wraps each DrawDisplayList/picture in `saveLayer(alpha)`
  /// (dl_dispatcher.cc:803-810).
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
    // TransformLayer.transform (transform_layer.cc:49).
    final nodeCtm = ctm.clone()..translate(node.offset.dx, node.offset.dy);
    final nodeTransform = node.transform;
    if (nodeTransform != null) {
      nodeCtm.multiply(nodeTransform);
    }

    final summary = SubtreeSummary();

    switch (node.type) {
      case 'OpacityLayer':
        if (node.alpha == 255) {
          // alpha==255: applyOpacity no-ops (layer_state_stack.cc:540).
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
        // Note: RenderOpacity._alpha==0 never creates a layer at all
        // (proxy_box.dart:949), so this path is unreachable from widgets —
        // kept for completeness on raw-layer inputs.
        // Opacity distributes per child ONLY when every child opts in to
        // kCallerCanApplyOpacity AND no child's paint_bounds intersect the
        // union of preceding children — otherwise one saveLayer(alpha)
        // wraps the whole group (container_layer.cc:131-153,
        // github.com/flutter/flutter/issues/93899).
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
          // canAcceptOpacity includes the internal-overlap flag —
          // children that self-overlap inside a transparent container
          // zero the aggregate renderable flags (container_layer.cc:151).
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
              debugLabel: 'Opacity(${node.creator ?? 'group'})',
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
        // paint_bounds = children ∪ local_cull_rect
        // (backdrop_filter_layer.cc:51-54) — contributes to the parent's
        // op-level overlap check even though coverage floods anyway.
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
            canDistributeOpacity: false,
            // backdrop layers are unbounded (dl_builder.cc:532)
            debugLabel: 'BackdropFilter(${node.creator ?? ''})',
            ctmScale: _basisScaleXY(nodeCtm),
          ),
        );
        out.addAll(children);
        out.add(MRestore());
        childSummary.hasBackdrop = true;
        final s = _scopedContribution(
          childSummary,
          compositeBlend: node.blendMode ?? ui.BlendMode.srcOver,
        );
        s.hasBackdrop = true;
        // The op's contributed bounds are paint_bounds (children ∪ cull
        // rect) — accumulate, not clamp, so the cull union lands in the
        // parent's op-level overlap check.
        if (bounds != null) {
          s.accumulator.accumulate(bounds);
          s.opRects
            ..clear()
            ..add(bounds);
        }
        return s;

      case 'ImageFilterLayer':
        // layer_state_stack: an outstanding image filter folds into an
        // accepting child's saveLayer paint (kSaveLayerRenderFlags) —
        // only wrap a group saveLayer when a child can't take it or
        // children overlap.
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
            debugLabel: 'ImageFilter(${node.creator ?? ''})',
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
              // Real MTB decision from the layer's own colorFilter
              // (layer.dart:1964) — a luminance matrix stays tight.
              colorFilterAffectsTransparentBlack:
                  node.colorFilterAffectsTransparentBlack ||
                  inheritedColorFilterMTB,
              imageFilter: inheritedImageFilter,
            ),
            bounds: cfPass.union.bounds,
            debugLabel: 'ColorFilter(${node.creator ?? ''})',
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
        // shader_mask_layer.cc:68: saveLayer(paint_bounds) + children +
        // DrawPaint(shader, blend).
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
            // shader_mask_layer.cc:68: saveLayer(paint_bounds) — child
            // paint bounds; maskRect only defines the shader rect.
            bounds: childSummary.bounds,
            debugLabel: 'ShaderMask(${node.creator ?? ''})',
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
          // clip_shape_layer.h:104: ApplyClip then saveLayer(paint_bounds).
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
                // paint_bounds contains clip-adjusted content
                // (clip_shape_layer.h:66) → kContainsContents; the saveLayer
                // peepholes when content is group-compatible
                // (dl_builder.cc:723, dl_dispatcher.cc:330).
                canDistributeOpacity:
                    childSummary.isGroupOpacityCompatible &&
                    !childSummary.unbounded,
                debugLabel: 'clip-saveLayer(${node.type})',
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
        final pi = _picMatch[node];
        final ops = pi != null && pi < pictures.length
            ? pictures[pi]
            : const <RecordedOp>[];
        if (inheritedAlpha < 1.0) {
          // drawDisplayList with opacity → saveLayer(alpha) around the whole
          // picture (dl_dispatcher.cc:803-810), can_distribute =
          // can_apply_group_opacity.
          final children = <MOp>[];
          final picSummary = _emitPicture(
            ops,
            nodeCtm,
            children,
            canvasBounds: node.canvasBounds == null
                ? null
                : _transformRect(nodeCtm, node.canvasBounds!),
          );
          out.add(
            MSaveLayer(
              paint: MPaint(alpha: inheritedAlpha),
              bounds: picSummary.bounds,
              // can_apply_group_opacity passed directly — no
              // content_is_unbounded gate here (dl_dispatcher.cc:809-813).
              canDistributeOpacity: picSummary.isGroupOpacityCompatible,
              debugLabel: 'Opacity(${node.creator ?? 'picture'})',
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
        );
        // An unwrapped drawDisplayList's ops draw inline in the parent pass:
        // internal blends propagate, and the op contributes one bounds rect.
        picSummary.opBlendMode = picSummary.maxBlendMode;
        return picSummary;

      case 'TextureLayer':
      case 'PlatformViewLayer':
        // Contributes its rect bounds to the parent accumulator — a platform
        // view or texture overlapping siblings must still poison a group
        // opacity check (it's an opacity-compatible draw op).
        out.add(MDraw(name: node.type));
        // PlatformViewLayer.rect is ALREADY in global space (layer.dart:
        // 1009); TextureLayer.rect is layer-local — transform it.
        final r = node.rect == null
            ? null
            : (node.type == 'PlatformViewLayer'
                  ? node.rect!
                  : _transformRect(nodeCtm, node.rect!));
        if (r != null) {
          summary.accumulator.accumulate(r);
          summary.opRects.add(r);
        }
        // Platform views can't apply outstanding opacity — forces group
        // saveLayer under Opacity (they never set renderable_state_flags).
        // display_list_layer.cc:104: pictures advertise opacity ONLY —
        // no kCallerCanApplyColorFilter/ImageFilter.
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
      // contains_backdrop_filter is copied into the saveLayer op's
      // options (dl_builder.cc:719-721) but never propagates back to the
      // parent scope — backdrops nested in a saveLayer must NOT mark the
      // enclosing scope.
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
      // can_apply_group_opacity (dl_builder.cc:1819): an internally
      // overlapping or incompatible picture poisons the parent group check.
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

  /// The opacity-compatibility of a *layer-as-an-op* in the parent's group
  /// check — dl_builder.cc:548-554 + :630-638: a saveLayer op poisons the
  /// parent only when it `renders_with_attributes()` AND (its paint isn't
  /// opacity-compatible OR it has an image filter). A backdrop saveLayer
  /// with the default srcOver paint has NO attributes → compatible.
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
  }) {
    // dl_dispatcher.cc:809-844: drawDisplayList runs inside its own
    // save/restore scope — the child list may alter the clip, and that must
    // not leak into subsequent sibling ops.
    out.add(MSave());
    final summary = SubtreeSummary()..acceptsColorFilter = false;
    final scopes = <_PicScope>[_PicScope(summary)];
    scopes.first.cullBounds = canvasBounds;
    for (final op in ops) {
      _emitRecordedOp(op, layerCtm, scopes, out);
    }
    // dl_builder Build(): `while (save_stack_.size() > 1) restore()` —
    // auto-restore any save/saveLayer left open inside the picture.
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
          debugLabel: 'canvas.saveLayer',
          ctmScale: opScale,
        );
        out.add(msl);
        scopes.add(
          _PicScope.saveLayer(msl)
            ..hasValidClip = _currentScope(scopes).hasValidClip
            ..clipBounds = _currentScope(scopes).clipBounds
            ..cullBounds = _currentScope(scopes).cullBounds,
        );
      case 'clipRect':
      case 'clipRRect':
      case 'clipRSuperellipse':
      case 'clipPath':
        if (op.clipRect != null) {
          // has_valid_clip is set by BOTH clip kinds
          // (dl_builder.cc:1053/1084/1120/1156); only intersect narrows
          // the bounds — a difference clip subtracts coverage but the
          // bounding rect is the pre-difference clip.
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
        // dl_builder.cc:1855, :1882: no guarantee glyphs/shadow shapes don't
        // overlap → UpdateLayerOpacityCompatibility(false).
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
          // UpdateCurrentOpacityCompatibility (dl_builder.h:736): no color
          // filter, no invert, no runtime shader, srcOver blend.
          // dl_builder.h:736: no color filter, no invert, no runtime
          // effect, opacity-compatible blend.
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
          // AccumulateUnbounded ALWAYS accumulates the local cull coverage
          // (clip bounds, else the picture's cull rect); is_unbounded is
          // set only when there is no valid clip (dl_builder.cc:1949-1965).
          summary.accumulator.accumulate(scope.clipBounds ?? scope.cullBounds);
          if (!scope.hasValidClip) {
            summary.unbounded = true;
          }
        } else {
          summary.accumulator.accumulate(bounds);
        }
        out.add(
          MDraw(
            name: op.name,
            blendMode: blendMode,
            bounds: bounds,
            imageFilter: paint?.imageFilter,
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
    // can_distribute_opacity = is_group_opacity_compatible &&
    // !content_is_unbounded (dl_builder.cc:723, dl_dispatcher.cc:333).
    msl.canDistributeOpacity =
        content.isGroupOpacityCompatible && !content.unbounded;
    // dl_builder.cc:710-716: layer_op->rect = content_bounds ALWAYS —
    // intersected with user bounds when caller-supplied (which also sets
    // content_is_clipped → kMayClipContents). dl_dispatcher.cc:319-328:
    // unbounded content + caller bounds keeps caller bounds; unbounded +
    // no caller bounds → impeller_bounds = null → flood to coverage limit.
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
    // parent's group-opacity check (dl_builder.cc:630-638).
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
    // hasBackdrop deliberately NOT propagated — contains_backdrop_filter
    // dies at each saveLayer boundary (dl_builder.cc:719-721).
    // The saveLayer's own composite blend applies in the parent pass;
    // blends INSIDE the saveLayer composite against the subpass texture
    // and never reach the parent's max (dl_dispatcher.cc:942-951).
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

  /// `has_valid_clip` (dl_builder.h:623): set by ANY clip op — intersect
  /// or difference — and inherited by scopes pushed inside (dl_builder.h:604,
  /// dl_builder.cc:1053/1084/1120/1156).
  bool hasValidClip = false;

  /// The scope's current clip bounds (from intersect clips only — a
  /// difference clip marks validity but doesn't narrow the bound).
  Rect? clipBounds;

  /// The scope's cull coverage — the picture's `canvasBounds` — used when
  /// `hasValidClip` is set by a difference clip with no intersect bound.
  Rect? cullBounds;
}
