import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart' show DebugCreator;

import 'creation_location.dart';
import 'recorded_op.dart';
import 'scene_recording.dart';

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

/// The engine layer [layer]'s last `addToScene` pushed, which keys its
/// recorded scene node.
///
/// `Layer.engineLayer` is protected and visible for testing; this package only
/// runs inside widget tests, and reading it changes nothing.
ui.EngineLayer? _engineLayerOf(Layer layer) =>
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    layer.engineLayer;

/// Walks the composited layer tree after a pump.
///
/// Traversal uses `ContainerLayer.firstChild` / `Layer.nextSibling`; each
/// PictureLayer's ops are found by picture identity through [opsFor].
///
/// Framework layer types are read from their fields. Any other layer type
/// (a package's own `Layer` subclass) is rebuilt from the pushes it sent to
/// the engine, found through [sceneFor] by its `engineLayer`.
class LayerWalker {
  LayerWalker(this.opsFor, {this.sceneFor, this.lastScene});

  /// Looks up the ops recorded for a picture, or null if it was recorded
  /// outside the binding.
  final List<RecordedOp>? Function(ui.Picture picture) opsFor;

  /// Looks up what an engine layer's push recorded.
  final SceneNode? Function(ui.EngineLayer engineLayer)? sceneFor;

  /// The scene the engine received for the last frame.
  final SceneNode? Function()? lastScene;

  /// Number of PictureLayers in the last walk whose ops were unknown.
  int missingPictures = 0;

  /// Where those pictures sit: their own or nearest ancestor's widget.
  final Set<String> missingPictureOrigins = {};

  /// Custom layer types in the last walk that were read from their scene
  /// pushes.
  final Set<String> sceneLayers = {};

  /// Custom layer types in the last walk whose effect is unknown, estimated
  /// as plain containers: their engine layer came from a scene the binding
  /// did not record (a `toImage` snapshot), or the scene holds pushes no
  /// layer accounts for. [unattributedPushes] stands for pushes whose layer
  /// cannot be named.
  final Set<String> unmodeledLayers = {};

  /// The [unmodeledLayers] entry for pushes no layer accounts for.
  static const unattributedPushes = '(unattributed scene pushes)';

  /// Engine layers the walk accounted for: framework layers' own and every
  /// push read for a custom layer.
  final Set<ui.EngineLayer> _accounted = {};

  /// Custom container types without an engine layer. Usually they pushed
  /// nothing (only their children), which is how the model treats them.
  final Set<String> _pushless = {};

  /// Framework layers by the engine layer or picture their scene node is
  /// keyed by, for the whole tree of the current walk.
  final Map<ui.EngineLayer, Layer> _layerByEngineLayer = {};
  final Map<ui.Picture, Layer> _layerByPicture = {};

  /// Whether some framework layer holds an engine layer the last recorded
  /// scene does not contain: a `toImage` snapshot replaced it after that
  /// scene was built. The scene then cannot be matched against the tree.
  bool _staleScene = false;

  /// `BackdropKey`s by the int id the engine received, so framework and
  /// scene-read backdrops compare by the same identity. Kept across walks.
  final Map<int, Object> _backdropKeys = {};

  CapturedLayer walk(Layer root) {
    missingPictures = 0;
    missingPictureOrigins.clear();
    sceneLayers.clear();
    unmodeledLayers.clear();
    _accounted.clear();
    _pushless.clear();
    _layerByEngineLayer.clear();
    _layerByPicture.clear();
    _staleScene = false;
    if (sceneFor != null) {
      _indexFramework(root);
    }
    final captured = _node(root);
    final scene = lastScene?.call();
    if (scene != null && !_staleScene && _hasOrphanPush(scene)) {
      unmodeledLayers.addAll(
        _pushless.isEmpty ? const {unattributedPushes} : _pushless,
      );
    }
    return captured;
  }

  bool _hasOrphanPush(SceneNode node) {
    final engineLayer = node.engineLayer;
    if (engineLayer != null && !_accounted.contains(engineLayer)) {
      return true;
    }
    return node.children.any(_hasOrphanPush);
  }

  /// Fills [_layerByEngineLayer], [_layerByPicture] and [_backdropKeys].
  void _indexFramework(Layer layer) {
    if (layer is PictureLayer) {
      final picture = layer.picture;
      if (picture != null) {
        _layerByPicture[picture] = layer;
      }
      return;
    }
    final engineLayer = _engineLayerOf(layer);
    if (engineLayer != null) {
      _layerByEngineLayer[engineLayer] = layer;
      final recorded = sceneFor?.call(engineLayer);
      if (recorded == null) {
        _staleScene = true;
      }
      final key = layer is BackdropFilterLayer ? layer.backdropKey : null;
      final id = recorded?.backdropId;
      if (key != null && id != null) {
        _backdropKeys[id] = key;
      }
    }
    if (layer is ContainerLayer) {
      var child = layer.firstChild;
      while (child != null) {
        _indexFramework(child);
        child = child.nextSibling;
      }
    }
  }

  /// The framework's own layer types: the model reads their fields.
  static const _frameworkTypes = {
    'ContainerLayer',
    'OffsetLayer',
    'TransformLayer',
    'OpacityLayer',
    'ClipRectLayer',
    'ClipRRectLayer',
    'ClipRSuperellipseLayer',
    'ClipPathLayer',
    'ColorFilterLayer',
    'ImageFilterLayer',
    'BackdropFilterLayer',
    'ShaderMaskLayer',
    'PictureLayer',
    'TextureLayer',
    'PlatformViewLayer',
    'PerformanceOverlayLayer',
    'LeaderLayer',
    'FollowerLayer',
  };

  static bool _isFrameworkType(String type) =>
      _frameworkTypes.contains(type) || type.startsWith('AnnotatedRegionLayer');

  /// The framework type a leaf layer subclass is read as. Containers keep
  /// their own type: a subclass may push nothing of its base class's effect.
  static String? _leafTypeOf(Layer layer) => switch (layer) {
    PictureLayer() => 'PictureLayer',
    TextureLayer() => 'TextureLayer',
    PlatformViewLayer() => 'PlatformViewLayer',
    PerformanceOverlayLayer() => 'PerformanceOverlayLayer',
    _ => null,
  };

  CapturedLayer _node(Layer layer) {
    final own = _engineLayerOf(layer);
    if (own != null) {
      _accounted.add(own);
    }
    var type = layer.runtimeType.toString();
    if (!_isFrameworkType(type)) {
      if (own != null) {
        final recorded = sceneFor?.call(own);
        if (recorded != null) {
          sceneLayers.add(type);
          return _fromScene(recorded, layer, _customOrigin(layer));
        }
        // Its engine layer came from a scene the binding did not record.
        unmodeledLayers.add(type);
      } else if (layer is ContainerLayer) {
        _pushless.add(type);
      }
      // A leaf subclass draws like its framework type.
      type = _leafTypeOf(layer) ?? type;
    }

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
        missingPictureOrigins.add(_customOrigin(layer).label);
      }
    }

    final origin = _originOf(layer);

    return CapturedLayer(
      type: type,
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
          ? _backdropIdentity(layer)
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

  WidgetOrigin? _originOf(Layer layer) {
    final dc = layer.debugCreator;
    return dc is DebugCreator ? (_origins[dc] ??= describeCreator(dc)) : null;
  }

  /// [layer]'s own origin, or its type inside the nearest ancestor that has
  /// one: custom layers rarely set `debugCreator`.
  WidgetOrigin _customOrigin(Layer layer) {
    final own = _originOf(layer);
    if (own != null) {
      return own;
    }
    final type = layer.runtimeType.toString();
    for (Layer? a = layer.parent; a != null; a = a.parent) {
      final origin = _originOf(a);
      if (origin != null) {
        return WidgetOrigin(
          widget: '$type in ${origin.widget}',
          path: [type, ...origin.path],
          location: origin.location,
        );
      }
    }
    return WidgetOrigin(widget: type, path: [type]);
  }

  /// The identity the model groups backdrops by: the layer's `BackdropKey`.
  Object? _backdropIdentity(BackdropFilterLayer layer) => layer.backdropKey;

  /// A custom layer's pushes as layers the model reads. Children that are
  /// framework layers are walked as usual, so they keep their origins; the
  /// rest carries [origin], the owner's.
  CapturedLayer _fromScene(SceneNode node, Layer owner, WidgetOrigin origin) {
    final nodeEngineLayer = node.engineLayer;
    if (nodeEngineLayer != null) {
      _accounted.add(nodeEngineLayer);
    }
    final children = <CapturedLayer>[];
    for (final child in node.children) {
      final childEngineLayer = child.engineLayer;
      final childPicture = child.picture;
      final layer = childEngineLayer != null
          ? _layerByEngineLayer[childEngineLayer]
          : childPicture != null
          ? _layerByPicture[childPicture]
          : null;
      children.add(
        layer != null && layer != owner
            ? _node(layer)
            : _fromScene(child, owner, origin),
      );
    }

    List<RecordedOp>? pictureOps;
    var pictureMissing = false;
    final picture = node.picture;
    if (picture != null) {
      pictureOps = opsFor(picture);
      if (pictureOps == null) {
        pictureMissing = true;
        missingPictures++;
        missingPictureOrigins.add(origin.label);
      }
    }

    return CapturedLayer(
      type: node.type,
      children: children,
      pictureOps: pictureOps,
      pictureMissing: pictureMissing,
      origin: origin,
      offset: node.offset,
      transform: node.transform,
      alpha: node.alpha,
      filter: node.filter,
      blendMode: node.blendMode,
      backdropKeyIdentity: switch (node.backdropId) {
        final id? => _backdropKeys[id] ?? id,
        null => null,
      },
      clipBounds: node.clipBounds,
      clipBehaviorName: node.clipBehaviorName,
      maskRect: node.maskRect,
      hasShader: node.hasShader,
      colorFilterAffectsTransparentBlack:
          node.colorFilterAffectsTransparentBlack,
      rect: node.rect,
    );
  }
}
