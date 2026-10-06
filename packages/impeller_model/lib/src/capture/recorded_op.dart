/// What the recording canvas captures per op, and how filters and paints
/// are read back from `dart:ui` objects that don't expose their fields.
library;

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../engine/color_filter.dart';

/// Description of an image filter.
///
/// `dart:ui` image filters are private classes with no public accessors for
/// their parameters, so they are read from `toString()` (and, for compose,
/// from the private class's public fields via `dynamic`). If an SDK bump
/// changes these formats, `tool/engine_refs.dart` flags the quotes below.
class FilterDesc {
  const FilterDesc.gaussianBlur(this.sigmaX, this.sigmaY, {this.source})
    : kind = 'blur',
      inner = null,
      outer = null;
  const FilterDesc.matrix({this.source})
    : kind = 'matrix',
      sigmaX = 0,
      sigmaY = 0,
      inner = null,
      outer = null;

  /// `inner` runs first, `outer` consumes its result.
  const FilterDesc.compose(this.inner, this.outer, {this.source})
    : kind = 'compose',
      sigmaX = 0,
      sigmaY = 0;
  const FilterDesc.other(this.kind, {this.source})
    : sigmaX = 0,
      sigmaY = 0,
      inner = null,
      outer = null;

  /// The originating `ui.ImageFilter`. All filter classes implement
  /// content `operator==`, so equality is exact.
  final ui.ImageFilter? source;

  final String kind;
  final double sigmaX;
  final double sigmaY;
  final FilterDesc? inner;
  final FilterDesc? outer;

  bool isSameFilter(FilterDesc other) {
    if (source != null && other.source != null) {
      return source == other.source;
    }
    return toString() == other.toString();
  }

  /// ```engine lib/ui/painting.dart
  ///   String toString() => 'ImageFilter.blur($sigmaX, $sigmaY, $_modeString${_boundsString()})';
  /// ```
  static final _blurRe = RegExp(
    r'^ImageFilter\.blur\(([\d.eE+-]+), ([\d.eE+-]+)',
  );

  static FilterDesc? describe(ui.ImageFilter? filter) {
    if (filter == null) {
      return null;
    }
    final s = filter.toString();
    final blur = _blurRe.firstMatch(s);
    if (blur != null) {
      final sx = double.tryParse(blur.group(1)!);
      final sy = double.tryParse(blur.group(2)!);
      if (sx == null || sy == null) {
        return FilterDesc.other('blur?', source: filter);
      }
      // The engine drops a blur that would not change anything: the layer
      // or paint then has no filter at all. SK_ScalarNearlyZero is
      // 1 / (1 << 12) (Skia's SkScalar.h, not in the Flutter SDK).
      //
      // ```engine display_list/effects/image_filters/dl_blur_image_filter.cc
      //   if (!std::isfinite(sigma_x) || !std::isfinite(sigma_y)) {
      //     return nullptr;
      //   }
      //   if (sigma_x < SK_ScalarNearlyZero && sigma_y < SK_ScalarNearlyZero) {
      //     return nullptr;
      //   }
      // ```
      const nearlyZero = 1 / (1 << 12);
      if (!sx.isFinite ||
          !sy.isFinite ||
          (sx < nearlyZero && sy < nearlyZero)) {
        return null;
      }
      return FilterDesc.gaussianBlur(sx, sy, source: filter);
    }
    // ```engine lib/ui/painting.dart
    //   String toString() => 'ImageFilter.matrix($data, $filterQuality)';
    // ```
    if (s.startsWith('ImageFilter.matrix(')) {
      return FilterDesc.matrix(source: filter);
    }
    // ```engine lib/ui/painting.dart
    // class _ComposeImageFilter implements ImageFilter {
    //   _ComposeImageFilter({required this.innerFilter, required this.outerFilter});
    //
    //   final ImageFilter innerFilter;
    //   final ImageFilter outerFilter;
    // ```
    if (s.startsWith('ImageFilter.compose(')) {
      try {
        // Private engine type without a public accessor; guarded by the
        // toString() check above and the catch below.
        final dynamic d = filter;
        return FilterDesc.compose(
          // ignore: avoid_dynamic_calls
          describe(d.innerFilter as ui.ImageFilter),
          // ignore: avoid_dynamic_calls
          describe(d.outerFilter as ui.ImageFilter),
          source: filter,
        );
      } on Object {
        return FilterDesc.other('compose?', source: filter);
      }
    }
    // ```engine lib/ui/painting.dart
    //   String toString() => 'ImageFilter.dilate($radiusX, $radiusY)';
    // ```
    if (s.startsWith('ImageFilter.dilate(')) {
      return FilterDesc.other('dilate', source: filter);
    }
    // ```engine lib/ui/painting.dart
    //   String toString() => 'ImageFilter.erode($radiusX, $radiusY)';
    // ```
    if (s.startsWith('ImageFilter.erode(')) {
      return FilterDesc.other('erode', source: filter);
    }
    // A `ui.ColorFilter` is also an `ImageFilter`.
    if (s.startsWith('ColorFilter.')) {
      return FilterDesc.other('colorFilter', source: filter);
    }
    if (s.startsWith('ImageFilter.shader(')) {
      return FilterDesc.other('shader', source: filter);
    }
    return FilterDesc.other('unknown', source: filter);
  }

  Map<String, Object?> toJson() => {
    'kind': kind,
    if (kind == 'blur') 'sigmaX': sigmaX,
    if (kind == 'blur') 'sigmaY': sigmaY,
    if (inner != null) 'inner': inner!.toJson(),
    if (outer != null) 'outer': outer!.toJson(),
  };

  @override
  String toString() => switch (kind) {
    'blur' => 'blur($sigmaX, $sigmaY)',
    'compose' => 'compose($inner → $outer)',
    _ => kind,
  };
}

/// A single recorded `dart:ui` canvas operation, including the paint
/// attributes the pass model needs and the op's bounds transformed into the
/// owning picture's coordinate space.
class RecordedOp {
  RecordedOp({
    required this.name,
    required this.ctm,
    this.bounds,
    this.paint,
    this.clipRect,
    this.clipOpIsIntersect = true,
    this.saveLayerPaint,
    this.saveLayerBounds,
    this.restoreToCount,
    this.blendMode,
    this.unbounded = false,
    this.forcesOverlap = false,
    this.contentId,
  });

  final String name;

  /// The canvas transform at the time the op was recorded (picture space).
  final Matrix4 ctm;

  /// Op bounds in picture space (already transformed by [ctm]). Null when
  /// unbounded or unknown.
  final Rect? bounds;

  final PaintAttrs? paint;

  /// For clip ops: the clip's axis-aligned bounds in picture space.
  final Rect? clipRect;
  final bool clipOpIsIntersect;

  /// For `saveLayer`: the caller-provided bounds (may be null) and paint.
  final Rect? saveLayerBounds;
  final PaintAttrs? saveLayerPaint;

  /// For `restoreToCount`: the target save count.
  final int? restoreToCount;

  /// The explicit blend-mode argument on drawVertices/drawAtlas, which
  /// overrides the paint's blend for blend decisions.
  final ui.BlendMode? blendMode;

  /// True for ops whose coverage is unbounded (drawPaint, drawColor, ...).
  final bool unbounded;

  /// True for ops whose primitives count as overlapping for group opacity
  /// (points, vertices, atlas).
  final bool forcesOverlap;

  /// `identityHashCode` of the drawn object (Path, Paragraph, Image,
  /// Picture, Vertices) when the op draws one. Only used to tell whether a
  /// frame changed: a new object counts as a change.
  final int? contentId;

  /// A stable string of everything recorded about this op, used to detect
  /// frames whose output did not change.
  String get signature => [
    name,
    bounds,
    clipRect,
    clipOpIsIntersect,
    saveLayerBounds,
    restoreToCount,
    blendMode,
    contentId,
    paint?.signature,
    saveLayerPaint?.signature,
    ctm.storage.join(','),
  ].join('|');

  Map<String, Object?> toJson() => {
    'op': name,
    if (bounds != null) 'bounds': _jsonRect(bounds!),
    if (unbounded) 'unbounded': true,
    if (clipRect != null) 'clip': _jsonRect(clipRect!),
    if (paint != null) 'paint': paint!.toJson(),
    if (saveLayerPaint != null) 'saveLayerPaint': saveLayerPaint!.toJson(),
  };

  /// JSON can't encode Infinity/NaN: unbounded rects serialize as a string.
  static Object _jsonRect(Rect r) =>
      r.isFinite ? [r.left, r.top, r.right, r.bottom] : r.toString();
}

/// The `ui.Paint` attributes that participate in Impeller's pass decisions.
class PaintAttrs {
  PaintAttrs({
    required this.color,
    required this.blendMode,
    required this.isInvertColors,
    required this.style,
    required this.hasShader,
    required this.hasRuntimeShader,
    required this.hasColorFilter,
    required this.colorFilterMayAffectTransparentBlack,
    required this.maskBlurSigma,
    required this.imageFilter,
    this.shaderId,
    this.colorFilterDescription,
  });

  factory PaintAttrs.of(ui.Paint paint) {
    final cf = paint.colorFilter;
    return PaintAttrs(
      color: paint.color,
      blendMode: paint.blendMode,
      isInvertColors: paint.invertColors,
      style: paint.style,
      hasShader: paint.shader != null,
      // Only fragment shaders are "runtime effects"; gradients and image
      // shaders stay opacity-compatible.
      //
      // ```engine display_list/dl_builder.h
      //         !current_.usesRuntimeEffect() &&         //
      // ```
      hasRuntimeShader: paint.shader is ui.FragmentShader,
      shaderId: paint.shader == null ? null : identityHashCode(paint.shader),
      hasColorFilter: cf != null,
      colorFilterMayAffectTransparentBlack:
          cf != null && colorFilterModifiesTransparentBlack(cf),
      colorFilterDescription: cf?.toString(),
      maskBlurSigma: _maskBlurSigma(paint.maskFilter),
      imageFilter: FilterDesc.describe(paint.imageFilter),
    );
  }

  final ui.Color color;
  double get alpha => color.a;
  final ui.BlendMode blendMode;
  final bool isInvertColors;
  final ui.PaintingStyle style;
  final bool hasShader;
  final bool hasRuntimeShader;
  final int? shaderId;
  final bool hasColorFilter;
  final String? colorFilterDescription;

  /// `color_filter->modifies_transparent_black()`.
  final bool colorFilterMayAffectTransparentBlack;

  /// `Paint::mask_blur_descriptor` sigma, or 0.
  final double maskBlurSigma;

  final FilterDesc? imageFilter;

  String get signature => [
    color.toARGB32(),
    blendMode.index,
    isInvertColors,
    style.index,
    shaderId,
    colorFilterDescription,
    maskBlurSigma,
    imageFilter?.source.toString(),
  ].join(',');

  /// Reads `ColorFilter.toString()`:
  ///
  /// ```engine lib/ui/painting.dart
  ///         return 'ColorFilter.mode($_color, $_blendMode)';
  /// ```
  /// ```engine lib/ui/painting.dart
  ///         return 'ColorFilter.matrix($_matrix)';
  /// ```
  static bool colorFilterModifiesTransparentBlack(ui.ColorFilter f) {
    final s = f.toString();
    if (s.startsWith('ColorFilter.mode(')) {
      final alpha = RegExp(r'alpha:\s*([\d.]+)').firstMatch(s);
      final mode = RegExp(r'BlendMode\.(\w+)').firstMatch(s)?.group(1);
      final blend = ui.BlendMode.values
          .where((m) => m.name == mode)
          .firstOrNull;
      if (alpha == null || blend == null) {
        return true; // unparseable: conservative
      }
      return blendColorFilterModifiesTransparentBlack(
        blend,
        colorIsTransparent: double.parse(alpha.group(1)!) == 0,
      );
    }
    if (s.startsWith('ColorFilter.matrix(')) {
      final nums = RegExp(
        r'-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?',
      ).allMatches(s).map((m) => double.parse(m.group(0)!)).toList();
      return nums.length < 20 ||
          matrixColorFilterModifiesTransparentBlack(nums);
    }
    // linearToSrgbGamma / srgbToLinearGamma map 0 to 0.
    return false;
  }

  /// ```engine lib/ui/painting.dart
  ///   String toString() => 'MaskFilter.blur($_style, ${_sigma.toStringAsFixed(1)})';
  /// ```
  static double _maskBlurSigma(ui.MaskFilter? mf) {
    if (mf == null) {
      return 0;
    }
    final m = RegExp(
      r'MaskFilter\.blur\([^,]+, ([\d.eE+-]+)',
    ).firstMatch('$mf');
    return m != null ? double.parse(m.group(1)!) : 0;
  }

  Map<String, Object?> toJson() => {
    'alpha': alpha,
    'blend': blendMode.name,
    if (imageFilter != null) 'imageFilter': imageFilter!.toJson(),
    if (hasColorFilter) 'colorFilter': colorFilterDescription,
    if (maskBlurSigma > 0) 'maskBlurSigma': maskBlurSigma,
  };
}
