import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show DebugCreator;

import 'creation_location.dart';
import 'recorded_op.dart';

/// A node in the captured layer tree, with the properties the Impeller
/// model reads. Mirrors `Layer` subclasses in
/// packages/flutter/lib/src/rendering/layer.dart.
class CapturedLayer {
  CapturedLayer({
    required this.type,
    this.children = const [],
    this.pictureOps,
    this.pictureMissing = false,
    this.origin,
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

  /// The recorded ops of a PictureLayer's picture.
  final List<RecordedOp>? pictureOps;

  /// True for a PictureLayer whose picture was not recorded through the
  /// binding (so its ops are unknown).
  final bool pictureMissing;

  /// `debugCreator` based widget description, when available.
  final WidgetOrigin? origin;

  /// `BackdropFilter (lib/home.dart:42)`, for pass attribution.
  String? get creator => origin?.label;

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

  /// `PictureLayer.canvasBounds`: the cull rect of the recorded picture.
  final Rect? canvasBounds;

  /// `ColorFilterLayer.colorFilter->modifies_transparent_black()`.
  final bool colorFilterAffectsTransparentBlack;

  /// A string that changes whenever anything the GPU would draw for this
  /// subtree changes: layer properties plus the recorded draw ops.
  String get signature {
    final b = StringBuffer();
    void visit(CapturedLayer n) {
      b
        ..write(n.type)
        ..write(n.offset)
        ..write(n.transform?.storage.join(','))
        ..write(n.alpha)
        ..write(n.filter?.source)
        ..write(n.blendMode)
        ..write(n.clipBounds)
        ..write(n.maskRect)
        ..write(n.rect);
      if (n.pictureMissing) {
        b.write('?');
      }
      for (final op in n.pictureOps ?? const <RecordedOp>[]) {
        b
          ..write(op.signature)
          ..write(';');
      }
      b.write('[');
      n.children.forEach(visit);
      b.write(']');
    }

    visit(this);
    return b.toString();
  }

  Map<String, Object?> toJson() => {
    'type': type,
    if (origin != null) 'creator': origin!.toJson(),
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
    if (pictureOps != null) 'ops': [for (final op in pictureOps!) op.toJson()],
    if (pictureMissing) 'opsMissing': true,
    if (children.isNotEmpty)
      'children': children.map((c) => c.toJson()).toList(),
  };
}

/// Walks the composited layer tree after a pump.
///
/// Traversal uses `ContainerLayer.firstChild` / `Layer.nextSibling`; each
/// PictureLayer's ops are found by picture identity through [opsFor].
class LayerWalker {
  LayerWalker(this.opsFor);

  /// Looks up the ops recorded for a picture, or null if it was recorded
  /// outside the binding.
  final List<RecordedOp>? Function(ui.Picture picture) opsFor;

  /// Number of PictureLayers in the last walk whose ops were unknown.
  int missingPictures = 0;

  CapturedLayer walk(Layer root) {
    missingPictures = 0;
    return _node(root);
  }

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

    List<RecordedOp>? pictureOps;
    var pictureMissing = false;
    if (layer is PictureLayer) {
      final picture = layer.picture;
      pictureOps = picture == null ? const [] : opsFor(picture);
      if (pictureOps == null) {
        pictureMissing = true;
        missingPictures++;
      }
    }

    final dc = layer.debugCreator;
    final origin = dc is DebugCreator
        ? (_origins[dc] ??= describeCreator(dc))
        : null;

    return CapturedLayer(
      type: layer.runtimeType.toString(),
      children: children,
      pictureOps: pictureOps,
      pictureMissing: pictureMissing,
      origin: origin,
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

  /// Origins per creator object: the same render object keeps its creator
  /// across frames, and describing it walks the element ancestry.
  final Expando<WidgetOrigin> _origins = Expando();
}
