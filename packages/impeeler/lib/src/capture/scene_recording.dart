/// Records the layer instructions the framework sends to the engine.
///
/// The layer walk reads Flutter's layer tree by layer type. A custom `Layer`
/// subclass that pushes its own clips or filters in `addToScene` is invisible
/// to it; the engine still receives those pushes. Every frame is built
/// through [RendererBinding.createSceneBuilder]:
///
/// ```framework flutter/lib/src/rendering/view.dart
///       final ui.SceneBuilder builder = RendererBinding.instance.createSceneBuilder();
/// ```
///
/// so wrapping that builder sees exactly what the engine gets, whatever layer
/// class issued it. Every call is forwarded unchanged.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'recorded_op.dart';

/// One push or add, as the engine received it.
class SceneNode {
  SceneNode(this.type);

  /// The framework layer type this call corresponds to, e.g.
  /// `BackdropFilterLayer` for `pushBackdropFilter`.
  final String type;
  final List<SceneNode> children = [];

  /// The engine layer a push returned; null for adds.
  ui.EngineLayer? engineLayer;

  /// `addPicture`.
  ui.Picture? picture;

  Offset offset = Offset.zero;
  Matrix4? transform;
  int alpha = 255;
  FilterDesc? filter;
  BlendMode? blendMode;
  int? backdropId;
  Rect? clipBounds;
  String? clipBehaviorName;
  Rect? maskRect;
  bool hasShader = false;
  Rect? rect;
  bool colorFilterAffectsTransparentBlack = false;
}

/// Forwards every call to [_inner] and records it as a [SceneNode] tree.
class RecordingSceneBuilder implements ui.SceneBuilder {
  RecordingSceneBuilder(this._inner, this._byEngineLayer, this._onBuild);

  final ui.SceneBuilder _inner;

  /// Nodes by the engine layer their push returned. Kept across frames: an
  /// unchanged subtree comes back as `addRetained(engineLayer)` without its
  /// pushes.
  final Expando<SceneNode> _byEngineLayer;

  /// Receives the recorded scene when it is built.
  final void Function(SceneNode scene) _onBuild;

  final SceneNode _root = SceneNode('Scene');
  late final List<SceneNode> _stack = [_root];

  T _push<T extends ui.EngineLayer>(SceneNode node, T engineLayer) {
    node.engineLayer = engineLayer;
    _byEngineLayer[engineLayer] = node;
    _stack.last.children.add(node);
    _stack.add(node);
    return engineLayer;
  }

  void _add(SceneNode node) => _stack.last.children.add(node);

  @override
  ui.TransformEngineLayer pushTransform(
    Float64List matrix4, {
    ui.TransformEngineLayer? oldLayer,
  }) => _push(
    SceneNode('TransformLayer')..transform = Matrix4.fromFloat64List(matrix4),
    _inner.pushTransform(matrix4, oldLayer: oldLayer),
  );

  @override
  ui.OffsetEngineLayer pushOffset(
    double dx,
    double dy, {
    ui.OffsetEngineLayer? oldLayer,
  }) => _push(
    SceneNode('OffsetLayer')..offset = Offset(dx, dy),
    _inner.pushOffset(dx, dy, oldLayer: oldLayer),
  );

  @override
  ui.ClipRectEngineLayer pushClipRect(
    Rect rect, {
    Clip clipBehavior = Clip.antiAlias,
    ui.ClipRectEngineLayer? oldLayer,
  }) => _push(
    SceneNode('ClipRectLayer')
      ..clipBounds = rect
      ..clipBehaviorName = clipBehavior.name,
    _inner.pushClipRect(rect, clipBehavior: clipBehavior, oldLayer: oldLayer),
  );

  @override
  ui.ClipRRectEngineLayer pushClipRRect(
    RRect rrect, {
    Clip clipBehavior = Clip.antiAlias,
    ui.ClipRRectEngineLayer? oldLayer,
  }) => _push(
    SceneNode('ClipRRectLayer')
      ..clipBounds = rrect.outerRect
      ..clipBehaviorName = clipBehavior.name,
    _inner.pushClipRRect(rrect, clipBehavior: clipBehavior, oldLayer: oldLayer),
  );

  @override
  ui.ClipRSuperellipseEngineLayer pushClipRSuperellipse(
    ui.RSuperellipse rsuperellipse, {
    Clip clipBehavior = Clip.antiAlias,
    ui.ClipRSuperellipseEngineLayer? oldLayer,
  }) => _push(
    SceneNode('ClipRSuperellipseLayer')
      ..clipBounds = rsuperellipse.outerRect
      ..clipBehaviorName = clipBehavior.name,
    _inner.pushClipRSuperellipse(
      rsuperellipse,
      clipBehavior: clipBehavior,
      oldLayer: oldLayer,
    ),
  );

  @override
  ui.ClipPathEngineLayer pushClipPath(
    Path path, {
    Clip clipBehavior = Clip.antiAlias,
    ui.ClipPathEngineLayer? oldLayer,
  }) => _push(
    SceneNode('ClipPathLayer')
      ..clipBounds = path.getBounds()
      ..clipBehaviorName = clipBehavior.name,
    _inner.pushClipPath(path, clipBehavior: clipBehavior, oldLayer: oldLayer),
  );

  @override
  ui.OpacityEngineLayer pushOpacity(
    int alpha, {
    Offset? offset = Offset.zero,
    ui.OpacityEngineLayer? oldLayer,
  }) => _push(
    SceneNode('OpacityLayer')
      ..alpha = alpha
      ..offset = offset ?? Offset.zero,
    _inner.pushOpacity(alpha, offset: offset, oldLayer: oldLayer),
  );

  @override
  ui.ColorFilterEngineLayer pushColorFilter(
    ui.ColorFilter filter, {
    ui.ColorFilterEngineLayer? oldLayer,
  }) => _push(
    SceneNode('ColorFilterLayer')
      ..colorFilterAffectsTransparentBlack =
          PaintAttrs.colorFilterModifiesTransparentBlack(filter),
    _inner.pushColorFilter(filter, oldLayer: oldLayer),
  );

  @override
  ui.ImageFilterEngineLayer pushImageFilter(
    ui.ImageFilter filter, {
    Offset offset = Offset.zero,
    ui.ImageFilterEngineLayer? oldLayer,
  }) => _push(
    SceneNode('ImageFilterLayer')
      ..filter = FilterDesc.describe(filter)
      ..offset = offset,
    _inner.pushImageFilter(filter, offset: offset, oldLayer: oldLayer),
  );

  @override
  ui.BackdropFilterEngineLayer pushBackdropFilter(
    ui.ImageFilter filter, {
    BlendMode blendMode = BlendMode.srcOver,
    ui.BackdropFilterEngineLayer? oldLayer,
    int? backdropId,
  }) => _push(
    SceneNode('BackdropFilterLayer')
      ..filter = FilterDesc.describe(filter)
      ..blendMode = blendMode
      ..backdropId = backdropId,
    _inner.pushBackdropFilter(
      filter,
      blendMode: blendMode,
      oldLayer: oldLayer,
      backdropId: backdropId,
    ),
  );

  @override
  ui.ShaderMaskEngineLayer pushShaderMask(
    ui.Shader shader,
    Rect maskRect,
    BlendMode blendMode, {
    ui.ShaderMaskEngineLayer? oldLayer,
    FilterQuality filterQuality = FilterQuality.low,
  }) => _push(
    SceneNode('ShaderMaskLayer')
      ..maskRect = maskRect
      ..blendMode = blendMode
      ..hasShader = true,
    _inner.pushShaderMask(
      shader,
      maskRect,
      blendMode,
      oldLayer: oldLayer,
      filterQuality: filterQuality,
    ),
  );

  @override
  void pop() {
    if (_stack.length > 1) {
      _stack.removeLast();
    }
    _inner.pop();
  }

  @override
  void addRetained(ui.EngineLayer retainedLayer) {
    final node = _byEngineLayer[retainedLayer];
    if (node != null) {
      _add(node);
    }
    _inner.addRetained(retainedLayer);
  }

  @override
  void addPerformanceOverlay(int enabledOptions, Rect bounds) {
    _add(SceneNode('PerformanceOverlayLayer')..rect = bounds);
    _inner.addPerformanceOverlay(enabledOptions, bounds);
  }

  @override
  void addPicture(
    Offset offset,
    ui.Picture picture, {
    bool isComplexHint = false,
    bool willChangeHint = false,
  }) {
    // PictureLayer draws at Offset.zero; an offset becomes the parent's.
    final node = SceneNode('PictureLayer')..picture = picture;
    _add(
      offset == Offset.zero
          ? node
          : (SceneNode('OffsetLayer')
              ..offset = offset
              ..children.add(node)),
    );
    _inner.addPicture(
      offset,
      picture,
      isComplexHint: isComplexHint,
      willChangeHint: willChangeHint,
    );
  }

  @override
  void addTexture(
    int textureId, {
    Offset offset = Offset.zero,
    double width = 0.0,
    double height = 0.0,
    bool freeze = false,
    FilterQuality filterQuality = FilterQuality.low,
  }) {
    _add(
      SceneNode('TextureLayer')
        ..rect = Rect.fromLTWH(offset.dx, offset.dy, width, height),
    );
    _inner.addTexture(
      textureId,
      offset: offset,
      width: width,
      height: height,
      freeze: freeze,
      filterQuality: filterQuality,
    );
  }

  @override
  void addPlatformView(
    int viewId, {
    Offset offset = Offset.zero,
    double width = 0.0,
    double height = 0.0,
  }) {
    _add(
      SceneNode('PlatformViewLayer')
        ..rect = Rect.fromLTWH(offset.dx, offset.dy, width, height),
    );
    _inner.addPlatformView(
      viewId,
      offset: offset,
      width: width,
      height: height,
    );
  }

  @override
  ui.Scene build() {
    _onBuild(_root);
    return _inner.build();
  }
}
