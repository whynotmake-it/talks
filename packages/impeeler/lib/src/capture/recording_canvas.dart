import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:vector_math/vector_math_64.dart';

import 'recorded_op.dart';

/// A `dart:ui` [Canvas] proxy that forwards every call to a real canvas and
/// records a structured description of each op.
///
/// Installed by [ImpeelerBinding] through the framework's test hook:
///
/// ```framework flutter/lib/src/rendering/binding.dart
///   /// This hook enables test bindings to instrument the rendering layer.
///   ///
///   /// This is used by the [PaintingContext] after creating a [PictureRecorder]
///   /// using [createPictureRecorder].
///   Canvas createCanvas(ui.PictureRecorder recorder) => Canvas(recorder);
/// ```
class RecordingCanvas implements ui.Canvas {
  RecordingCanvas(this._inner, this._sink);

  final ui.Canvas _inner;
  final List<RecordedOp> _sink;

  final List<Matrix4> _ctmStack = [Matrix4.identity()];

  Matrix4 get _ctm => _ctmStack.last;

  void _record(RecordedOp op) => _sink.add(op);

  Rect? _xformBounds(Rect? localBounds) {
    if (localBounds == null) {
      return null;
    }
    return _transformRect(_ctm, localBounds);
  }

  static Rect _transformRect(Matrix4 m, Rect r) {
    final p0 = m.transform3(Vector3(r.left, r.top, 0));
    final p1 = m.transform3(Vector3(r.right, r.top, 0));
    final p2 = m.transform3(Vector3(r.left, r.bottom, 0));
    final p3 = m.transform3(Vector3(r.right, r.bottom, 0));
    final xs = [p0.x, p1.x, p2.x, p3.x];
    final ys = [p0.y, p1.y, p2.y, p3.y];
    double lo(double a, double b) => a < b ? a : b;
    double hi(double a, double b) => a > b ? a : b;
    return Rect.fromLTRB(
      xs.fold(xs[0], lo),
      ys.fold(ys[0], lo),
      xs.fold(xs[0], hi),
      ys.fold(ys[0], hi),
    );
  }

  Rect? _strokeAdjusted(Rect? bounds, ui.Paint paint) {
    if (bounds == null) {
      return null;
    }
    if (paint.style == ui.PaintingStyle.stroke && paint.strokeWidth > 0) {
      return bounds.inflate(paint.strokeWidth / 2);
    }
    return bounds;
  }

  void _draw(
    String name,
    Rect? localBounds,
    ui.Paint paint, {
    bool unbounded = false,
    Object? content,
  }) {
    _record(
      RecordedOp(
        name: name,
        ctm: _ctm.clone(),
        bounds: _xformBounds(_strokeAdjusted(localBounds, paint)),
        paint: PaintAttrs.of(paint),
        unbounded: unbounded,
        contentId: content == null ? null : identityHashCode(content),
      ),
    );
  }

  // ---------------------------------------------------------------- save ops

  @override
  void save() {
    _ctmStack.add(_ctm.clone());
    _record(RecordedOp(name: 'save', ctm: _ctm.clone()));
    _inner.save();
  }

  @override
  void saveLayer(Rect? bounds, ui.Paint paint) {
    _ctmStack.add(_ctm.clone());
    _record(
      RecordedOp(
        name: 'saveLayer',
        ctm: _ctm.clone(),
        saveLayerBounds: bounds == null ? null : _xformBounds(bounds),
        saveLayerPaint: PaintAttrs.of(paint),
      ),
    );
    _inner.saveLayer(bounds, paint);
  }

  @override
  void restore() {
    _record(RecordedOp(name: 'restore', ctm: _ctm.clone()));
    if (_ctmStack.length > 1) {
      _ctmStack.removeLast();
    }
    _inner.restore();
  }

  @override
  void restoreToCount(int count) {
    _record(
      RecordedOp(
        name: 'restoreToCount',
        ctm: _ctm.clone(),
        restoreToCount: count,
      ),
    );
    while (_ctmStack.length > count && _ctmStack.length > 1) {
      _ctmStack.removeLast();
    }
    _inner.restoreToCount(count);
  }

  @override
  int getSaveCount() => _inner.getSaveCount();

  @override
  Float64List getTransform() => _inner.getTransform();

  // --------------------------------------------------------------- transforms

  @override
  void translate(double dx, double dy) {
    _ctm.translate(dx, dy);
    _inner.translate(dx, dy);
  }

  @override
  void scale(double sx, [double? sy]) {
    _ctm.scale(sx, sy ?? sx);
    _inner.scale(sx, sy);
  }

  @override
  void rotate(double radians) {
    _ctm.rotateZ(radians);
    _inner.rotate(radians);
  }

  @override
  void skew(double sx, double sy) {
    // Column-major: produces x' = x + sx·y, y' = y + sy·x.
    _ctm.multiply(Matrix4(1, sy, 0, 0, sx, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1));
    _inner.skew(sx, sy);
  }

  @override
  void transform(Float64List matrix4) {
    _ctm.multiply(Matrix4.fromFloat64List(matrix4));
    _inner.transform(matrix4);
  }

  // -------------------------------------------------------------------- clips

  void _clip(
    String name,
    Rect? localBounds,
    ui.ClipOp clipOp,
    bool doAntiAlias,
  ) {
    _record(
      RecordedOp(
        name: name,
        ctm: _ctm.clone(),
        clipRect: _xformBounds(localBounds),
        clipOpIsIntersect: clipOp == ui.ClipOp.intersect,
        paint: PaintAttrs.of(ui.Paint()..isAntiAlias = doAntiAlias),
      ),
    );
  }

  @override
  void clipRect(
    ui.Rect rect, {
    ui.ClipOp clipOp = ui.ClipOp.intersect,
    bool doAntiAlias = true,
  }) {
    _clip('clipRect', rect, clipOp, doAntiAlias);
    _inner.clipRect(rect, clipOp: clipOp, doAntiAlias: doAntiAlias);
  }

  @override
  void clipRRect(ui.RRect rrect, {bool doAntiAlias = true}) {
    _clip('clipRRect', rrect.outerRect, ui.ClipOp.intersect, doAntiAlias);
    _inner.clipRRect(rrect, doAntiAlias: doAntiAlias);
  }

  @override
  void clipRSuperellipse(
    ui.RSuperellipse rsuperellipse, {
    bool doAntiAlias = true,
  }) {
    _clip(
      'clipRSuperellipse',
      rsuperellipse.outerRect,
      ui.ClipOp.intersect,
      doAntiAlias,
    );
    _inner.clipRSuperellipse(rsuperellipse, doAntiAlias: doAntiAlias);
  }

  @override
  void clipPath(ui.Path path, {bool doAntiAlias = true}) {
    _clip('clipPath', path.getBounds(), ui.ClipOp.intersect, doAntiAlias);
    _inner.clipPath(path, doAntiAlias: doAntiAlias);
  }

  @override
  ui.Rect getLocalClipBounds() => _inner.getLocalClipBounds();

  @override
  ui.Rect getDestinationClipBounds() => _inner.getDestinationClipBounds();

  // -------------------------------------------------------------------- draws

  @override
  void drawColor(ui.Color color, ui.BlendMode blendMode) {
    _record(
      RecordedOp(
        name: 'drawColor',
        ctm: _ctm.clone(),
        paint: PaintAttrs.of(
          ui.Paint()
            ..color = color
            ..blendMode = blendMode,
        ),
        unbounded: true,
      ),
    );
    _inner.drawColor(color, blendMode);
  }

  @override
  void drawLine(ui.Offset p1, ui.Offset p2, ui.Paint paint) {
    _draw('drawLine', ui.Rect.fromPoints(p1, p2), paint);
    _inner.drawLine(p1, p2, paint);
  }

  @override
  void drawPaint(ui.Paint paint) {
    _draw('drawPaint', null, paint, unbounded: true);
    _inner.drawPaint(paint);
  }

  @override
  void drawRect(ui.Rect rect, ui.Paint paint) {
    _draw('drawRect', rect, paint);
    _inner.drawRect(rect, paint);
  }

  @override
  void drawRRect(ui.RRect rrect, ui.Paint paint) {
    _draw('drawRRect', rrect.outerRect, paint);
    _inner.drawRRect(rrect, paint);
  }

  @override
  void drawDRRect(ui.RRect outer, ui.RRect inner, ui.Paint paint) {
    _draw('drawDRRect', outer.outerRect, paint);
    _inner.drawDRRect(outer, inner, paint);
  }

  @override
  void drawRSuperellipse(ui.RSuperellipse rsuperellipse, ui.Paint paint) {
    _draw('drawRSuperellipse', rsuperellipse.outerRect, paint);
    _inner.drawRSuperellipse(rsuperellipse, paint);
  }

  @override
  void drawOval(ui.Rect rect, ui.Paint paint) {
    _draw('drawOval', rect, paint);
    _inner.drawOval(rect, paint);
  }

  @override
  void drawCircle(ui.Offset c, double radius, ui.Paint paint) {
    _draw('drawCircle', ui.Rect.fromCircle(center: c, radius: radius), paint);
    _inner.drawCircle(c, radius, paint);
  }

  @override
  void drawArc(
    ui.Rect rect,
    double startAngle,
    double sweepAngle,
    bool useCenter,
    ui.Paint paint,
  ) {
    _draw('drawArc', rect, paint);
    _inner.drawArc(rect, startAngle, sweepAngle, useCenter, paint);
  }

  @override
  void drawPath(ui.Path path, ui.Paint paint) {
    _draw('drawPath', path.getBounds(), paint, content: path);
    _inner.drawPath(path, paint);
  }

  @override
  void drawImage(ui.Image image, ui.Offset offset, ui.Paint paint) {
    _draw(
      'drawImage',
      offset & ui.Size(image.width.toDouble(), image.height.toDouble()),
      paint,
      content: image,
    );
    _inner.drawImage(image, offset, paint);
  }

  @override
  void drawImageRect(ui.Image image, ui.Rect src, ui.Rect dst, ui.Paint paint) {
    _draw('drawImageRect', dst, paint, content: image);
    _inner.drawImageRect(image, src, dst, paint);
  }

  @override
  void drawImageNine(
    ui.Image image,
    ui.Rect center,
    ui.Rect dst,
    ui.Paint paint,
  ) {
    _draw('drawImageNine', dst, paint, content: image);
    _inner.drawImageNine(image, center, dst, paint);
  }

  @override
  void drawPicture(ui.Picture picture) {
    _record(
      RecordedOp(
        name: 'drawPicture',
        ctm: _ctm.clone(),
        contentId: identityHashCode(picture),
      ),
    );
    _inner.drawPicture(picture);
  }

  @override
  void drawParagraph(ui.Paragraph paragraph, ui.Offset offset) {
    _draw(
      'drawParagraph',
      offset & ui.Size(paragraph.width, paragraph.height),
      ui.Paint(),
      content: paragraph,
    );
    _inner.drawParagraph(paragraph, offset);
  }

  @override
  void drawPoints(
    ui.PointMode pointMode,
    List<ui.Offset> points,
    ui.Paint paint,
  ) {
    Rect? b;
    if (points.isNotEmpty) {
      var l = points.first.dx, t = points.first.dy, r = l, bo = t;
      for (final p in points) {
        l = l < p.dx ? l : p.dx;
        t = t < p.dy ? t : p.dy;
        r = r > p.dx ? r : p.dx;
        bo = bo > p.dy ? bo : p.dy;
      }
      b = ui.Rect.fromLTRB(l, t, r, bo);
    }
    _record(
      RecordedOp(
        name: 'drawPoints',
        ctm: _ctm.clone(),
        bounds: _xformBounds(b),
        paint: PaintAttrs.of(paint),
        // Point sub-primitives may overlap each other.
        forcesOverlap: true,
      ),
    );
    _inner.drawPoints(pointMode, points, paint);
  }

  @override
  void drawRawPoints(
    ui.PointMode pointMode,
    Float32List points,
    ui.Paint paint,
  ) {
    Rect? b;
    if (points.length >= 2) {
      var l = points[0], t = points[1], r = l, bo = t;
      for (var i = 0; i + 1 < points.length; i += 2) {
        l = l < points[i] ? l : points[i];
        t = t < points[i + 1] ? t : points[i + 1];
        r = r > points[i] ? r : points[i];
        bo = bo > points[i + 1] ? bo : points[i + 1];
      }
      b = ui.Rect.fromLTRB(l, t, r, bo);
    }
    _record(
      RecordedOp(
        name: 'drawRawPoints',
        ctm: _ctm.clone(),
        bounds: _xformBounds(b),
        paint: PaintAttrs.of(paint),
        forcesOverlap: true,
      ),
    );
    _inner.drawRawPoints(pointMode, points, paint);
  }

  @override
  void drawVertices(
    ui.Vertices vertices,
    ui.BlendMode blendMode,
    ui.Paint paint,
  ) {
    _record(
      RecordedOp(
        name: 'drawVertices',
        ctm: _ctm.clone(),
        blendMode: blendMode,
        paint: PaintAttrs.of(paint),
        // Vertices bounds are not readable from dart:ui; their
        // sub-primitives count as overlapping.
        forcesOverlap: true,
        unbounded: true,
        contentId: identityHashCode(vertices),
      ),
    );
    _inner.drawVertices(vertices, blendMode, paint);
  }

  @override
  void drawAtlas(
    ui.Image atlas,
    List<ui.RSTransform> transforms,
    List<ui.Rect> rects,
    List<ui.Color>? colors,
    ui.BlendMode? blendMode,
    ui.Rect? cullRect,
    ui.Paint paint,
  ) {
    _record(
      RecordedOp(
        name: 'drawAtlas',
        ctm: _ctm.clone(),
        bounds: _xformBounds(cullRect),
        blendMode: blendMode,
        paint: PaintAttrs.of(paint),
        unbounded: cullRect == null,
        // Atlas entries count as overlapping each other.
        forcesOverlap: true,
      ),
    );
    _inner.drawAtlas(
      atlas,
      transforms,
      rects,
      colors,
      blendMode,
      cullRect,
      paint,
    );
  }

  @override
  void drawRawAtlas(
    ui.Image atlas,
    Float32List rstTransforms,
    Float32List rects,
    Int32List? colors,
    ui.BlendMode? blendMode,
    ui.Rect? cullRect,
    ui.Paint paint,
  ) {
    _record(
      RecordedOp(
        name: 'drawRawAtlas',
        ctm: _ctm.clone(),
        bounds: _xformBounds(cullRect),
        blendMode: blendMode,
        paint: PaintAttrs.of(paint),
        unbounded: cullRect == null,
        forcesOverlap: true,
      ),
    );
    _inner.drawRawAtlas(
      atlas,
      rstTransforms,
      rects,
      colors,
      blendMode,
      cullRect,
      paint,
    );
  }

  @override
  void drawShadow(
    ui.Path path,
    ui.Color color,
    double elevation,
    bool transparentOccluder,
  ) {
    _record(
      RecordedOp(
        name: 'drawShadow',
        ctm: _ctm.clone(),
        bounds: _xformBounds(path.getBounds().inflate(elevation)),
        paint: PaintAttrs.of(ui.Paint()..color = color),
        contentId: identityHashCode(path),
      ),
    );
    _inner.drawShadow(path, color, elevation, transparentOccluder);
  }
}
