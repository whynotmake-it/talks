import 'package:flutter/rendering.dart';

import 'recorded_op.dart';

/// A node in the captured layer tree, with the properties the Impeller
/// model reads. Mirrors `Layer` subclasses in
/// packages/flutter/lib/src/rendering/layer.dart.
class CapturedLayer {
  CapturedLayer({
    required this.type,
    this.children = const [],
    this.pictureIndex,
    this.creator,
    this.offset = Offset.zero,
    this.transform,
    this.alpha = 255,
    this.filter,
    this.blendMode,
    this.backdropKeyIdentity,
    this.clipBounds,
    this.clipBehaviorName,
    this.maskRect,
    this.hasShader = false,
    this.rect,
    this.colorFilterAffectsTransparentBlack = false,
    this.canvasBounds,
  });

  final String type;
  final List<CapturedLayer> children;

  /// Index into `OpRecorderRegistry.pictures` for PictureLayer.
  int? pictureIndex;

  /// `debugCreator` based widget description, when available.
  final String? creator;

  /// OffsetLayer.offset (PictureLayers have no offset — they draw at
  /// Offset.zero; layer.dart:889).
  final Offset offset;

  /// TransformLayer.transform.
  final Matrix4? transform;

  /// OpacityLayer.alpha (0-255).
  final int alpha;

  /// BackdropFilterLayer.filter / ImageFilterLayer.filter, described.
  final FilterDesc? filter;

  /// BackdropFilterLayer.blendMode / ShaderMaskLayer.blendMode.
  final BlendMode? blendMode;

  /// Identity of BackdropFilterLayer.backdropKey (becomes engine backdrop_id).
  final Object? backdropKeyIdentity;

  /// Clip*Layer clip bounds in layer-local space.
  final Rect? clipBounds;
  final String? clipBehaviorName;

  /// ShaderMaskLayer.maskRect.
  final Rect? maskRect;
  final bool hasShader;

  /// TextureLayer.rect / PlatformViewLayer.rect — the layer's bounds in
  /// layer space (PlatformViewLayer is already in global space, see
  /// layer.dart:1009; we treat both as parent-space bounds).
  final Rect? rect;

  /// `PictureLayer.canvasBounds` (layer.dart:834) — the bounds used for
  /// the canvas that recorded this picture. Lets the synthesizer match
  /// pictures to layers by CONTENT rather than positional order —
  /// `createCanvas` calls happen in paint order, not tree order, so
  /// positional matching silently mis-assigns pictures.
  final Rect? canvasBounds;

  /// `ColorFilterLayer.colorFilter->modifies_transparent_black()` — real
  /// decision via [PaintAttrs.colorFilterModifiesTransparentBlack] rather
  /// than a blanket assumption (layer.dart:1964 exposes the getter).
  final bool colorFilterAffectsTransparentBlack;

  Map<String, Object?> toJson() => {
    'type': type,
    if (creator != null) 'creator': creator,
    if (offset != Offset.zero) 'offset': [offset.dx, offset.dy],
    if (transform != null) 'transform': transform!.storage,
    if (alpha != 255) 'alpha': alpha,
    if (filter != null) 'filter': filter!.toJson(),
    if (blendMode != null) 'blendMode': blendMode!.name,
    if (backdropKeyIdentity != null) 'backdropId': '$backdropKeyIdentity',
    if (clipBounds != null)
      'clip': [
        clipBounds!.left,
        clipBounds!.top,
        clipBounds!.right,
        clipBounds!.bottom,
      ],
    if (clipBehaviorName != null) 'clipBehavior': clipBehaviorName,
    if (pictureIndex != null) 'picture': pictureIndex,
    if (children.isNotEmpty)
      'children': children.map((c) => c.toJson()).toList(),
  };
}

/// Walks the composited layer tree after a pump.
///
/// `RenderObject.debugLayer` is at rendering/object.dart:3184; traversal via
/// `ContainerLayer.firstChild`/`lastChild`/`Layer.nextSibling` (layer.dart).
class LayerWalker {
  /// Assign pictureIndex values to PictureLayers in DFS order. `pictureCount`
  /// is the number of pictures recorded this frame; mismatches are reported.
  CapturedLayer? walk(Layer root, {required int pictureCount}) {
    _pictureCursor = 0;
    final result = _node(root);
    _mismatch = _pictureCursor != pictureCount
        ? (expectedLayers: _pictureCursor, recorders: pictureCount)
        : null;
    return result;
  }

  int _pictureCursor = 0;
  ({int expectedLayers, int recorders})? _mismatch;
  ({int expectedLayers, int recorders})? get mismatch => _mismatch;

  CapturedLayer _node(Layer layer) {
    final children = <CapturedLayer>[];
    if (layer is ContainerLayer) {
      var child = layer.firstChild;
      while (child != null) {
        children.add(_node(child));
        child = child.nextSibling;
      }
    }

    Rect? clipBounds;
    String? clipBehavior;
    if (layer is ClipRectLayer) {
      clipBounds = layer.clipRect;
      clipBehavior = layer.clipBehavior.name;
    } else if (layer is ClipRRectLayer) {
      clipBounds = layer.clipRRect?.outerRect;
      clipBehavior = layer.clipBehavior.name;
    } else if (layer is ClipRSuperellipseLayer) {
      clipBounds = layer.clipRSuperellipse?.outerRect;
      clipBehavior = layer.clipBehavior.name;
    } else if (layer is ClipPathLayer) {
      clipBounds = layer.clipPath?.getBounds();
      clipBehavior = layer.clipBehavior.name;
    }

    int? pictureIndex;
    if (layer is PictureLayer) {
      pictureIndex = _pictureCursor++;
    }

    String? creator;
    final dc = layer.debugCreator;
    if (dc != null) {
      creator = _describeCreator(dc);
    }

    return CapturedLayer(
      type: layer.runtimeType.toString(),
      children: children,
      pictureIndex: pictureIndex,
      creator: creator,
      offset: layer is OffsetLayer ? layer.offset : Offset.zero,
      transform: layer is TransformLayer ? layer.transform : null,
      alpha: layer is OpacityLayer ? (layer.alpha ?? 255) : 255,
      filter: layer is ImageFilterLayer
          ? FilterDesc.describe(layer.imageFilter)
          : layer is BackdropFilterLayer
          ? FilterDesc.describe(layer.filter)
          : null,
      blendMode: layer is BackdropFilterLayer
          ? layer.blendMode
          : layer is ShaderMaskLayer
          ? layer.blendMode
          : null,
      backdropKeyIdentity: layer is BackdropFilterLayer
          ? layer.backdropKey
          : null,
      clipBounds: clipBounds,
      clipBehaviorName: clipBehavior,
      maskRect: layer is ShaderMaskLayer ? layer.maskRect : null,
      hasShader: layer is ShaderMaskLayer && layer.shader != null,
      colorFilterAffectsTransparentBlack:
          layer is ColorFilterLayer &&
          layer.colorFilter != null &&
          PaintAttrs.colorFilterModifiesTransparentBlack(
            layer.colorFilter!,
          ),
      rect: layer is TextureLayer
          ? layer.rect
          : layer is PlatformViewLayer
          ? layer.rect
          : null,
      canvasBounds: layer is PictureLayer ? layer.canvasBounds : null,
    );
  }

  static String _describeCreator(Object? debugCreator) {
    // debugCreator is typically `Element`-like; keep it short.
    if (debugCreator == null) {
      return '?';
    }
    var s = '$debugCreator';
    if (s.length > 80) {
      s = '${s.substring(0, 77)}…';
    }
    return s;
  }
}
