import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

/// Description of an image filter, parsed from `ImageFilter.toString()`.
///
/// `dart:ui` image filters do not expose their parameters (`_sigmaX` et al are
/// private fields of `_GaussianBlurImageFilter`), so we recover them from the
/// debug string. This is a fragile but documented shortcut; engine versions
/// that change the format need the regexps updated.
class FilterDesc {
  const FilterDesc.gaussianBlur(this.sigmaX, this.sigmaY, {this.source})
    : kind = 'blur',
      matrix = null,
      inner = null,
      outer = null;
  const FilterDesc.matrix(this.matrix, {this.source})
    : kind = 'matrix',
      sigmaX = 0,
      sigmaY = 0,
      inner = null,
      outer = null;
  const FilterDesc.compose(this.inner, this.outer, {this.source})
    : kind = 'compose',
      sigmaX = 0,
      sigmaY = 0,
      matrix = null;
  const FilterDesc.other(this.kind, {this.source})
    : sigmaX = 0,
      sigmaY = 0,
      matrix = null,
      inner = null,
      outer = null;

  /// The originating `ui.ImageFilter` — all 3.47 filter impls have a real
  /// `operator==` comparing content (sigma, matrix data, inner/outer), so
  /// equality is exact rather than toString-based (painting.dart:4514).
  final ui.ImageFilter? source;

  /// Structural equality via the source filter's own `==`; falls back to a
  /// toString compare when the source is unavailable.
  bool isSameFilter(FilterDesc other) {
    if (source != null && other.source != null) {
      return source == other.source;
    }
    return toString() == other.toString();
  }

  final String kind;
  final double sigmaX;
  final double sigmaY;
  final Float64List? matrix;
  final FilterDesc? inner;
  final FilterDesc? outer;

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
      final sx = double.tryParse(blur.group(1) ?? '');
      final sy = double.tryParse(blur.group(2) ?? '');
      if (sx == null || sy == null || !sx.isFinite || !sy.isFinite) {
        return FilterDesc.other('blur?', source: filter);
      }
      return FilterDesc.gaussianBlur(sx, sy, source: filter);
    }
    if (s.startsWith('ImageFilter.matrix(')) {
      return FilterDesc.matrix(null, source: filter);
    }
    if (s.startsWith('ImageFilter.compose(')) {
      // toString exposes nested filters ('source -> blur(...) -> ... ->
      // result') but we model as a single opaque pass for now.
      return FilterDesc.other('compose', source: filter);
    }
    if (s.startsWith('ImageFilter.dilate(')) {
      return FilterDesc.other('dilate', source: filter);
    }
    if (s.startsWith('ImageFilter.erode(')) {
      return FilterDesc.other('erode', source: filter);
    }
    return FilterDesc.other('unknown', source: filter);
  }

  /// `ImageFilter.blur(bounds: ...)` — bounded-blur mode clamps the
  /// coverage (ui/painting.dart:4347, `_BlurImageFilter.bounds` —
  /// private class, read via dynamic).
  Rect? get blurBounds {
    if (kind != 'blur' || source == null) {
      return null;
    }
    try {
      return (source as dynamic).bounds as Rect?;
    } catch (_) {
      return null;
    }
  }

  /// Tile mode parsed from `ImageFilter.blur(...)`'s toString.
  String? get blurTileMode {
    if (kind != 'blur' || source == null) {
      return null;
    }
    final m = RegExp(
      r'ImageFilter\.blur\([^,]+, [^,]+, (\w+)',
    ).firstMatch(source.toString());
    return m?.group(1);
  }

  Map<String, Object?> toJson() => {
    'kind': kind,
    if (kind == 'blur') 'sigmaX': sigmaX,
    if (kind == 'blur') 'sigmaY': sigmaY,
    if (blurTileMode != null) 'tileMode': blurTileMode,
    if (blurBounds != null) 'bounds': blurBounds.toString(),
  };

  @override
  String toString() => kind == 'blur' ? 'blur($sigmaX,$sigmaY)' : kind;
}

/// A single recorded `dart:ui` canvas operation, including the paint
/// attributes the Impeller pass model needs and the op's bounds transformed
/// into the owning picture's coordinate space.
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
  });

  final String name;

  /// The canvas transform at the time the op was recorded (picture space).
  final Matrix4 ctm;

  /// Op bounds in picture space (already transformed by [ctm]).
  /// Null when unbounded or unknown.
  Rect? bounds;

  /// Snapshot of paint attributes for draw ops.
  PaintAttrs? paint;

  /// For clip ops: the clip's axis-aligned bounds in picture space.
  Rect? clipRect;
  bool clipOpIsIntersect;

  /// For `saveLayer`: the caller-provided bounds (may be null) and paint.
  Rect? saveLayerBounds;
  PaintAttrs? saveLayerPaint;

  /// For `restoreToCount`: the target save count.
  int? restoreToCount;

  /// The explicit blend-mode argument on drawVertices/drawAtlas/drawRawAtlas
  /// — the op's composite mode (DrawVerticesOp/DrawAtlasOp carry `mode`),
  /// which overrides the paint's blend for blend decisions.
  final ui.BlendMode? blendMode;

  /// True for ops whose coverage is unbounded (drawPaint, drawColor, ...).
  bool unbounded;

  /// True for ops whose primitives are treated as individually overlapping
  /// for group-opacity purposes (dl_builder.cc:1520, drawAtlas, drawVertices).
  bool forcesOverlap;

  Map<String, Object?> toJson() => {
    'op': name,
    if (bounds != null) 'bounds': _jsonRect(bounds!),
    if (unbounded) 'unbounded': true,
    if (clipRect != null) 'clip': _jsonRect(clipRect!),
    if (paint != null) 'paint': paint!.toJson(),
    if (saveLayerPaint != null) 'saveLayerPaint': saveLayerPaint!.toJson(),
  };

  /// JSON can't encode Infinity/NaN — unbounded rects serialize as
  /// a marker string.
  static Object _jsonRect(Rect r) =>
      r.isFinite ? [r.left, r.top, r.right, r.bottom] : r.toString();
}

/// The `ui.Paint` attributes that participate in Impeller's pass decisions.
class PaintAttrs {
  PaintAttrs({
    required this.alpha,
    required this.blendMode,
    required this.isAntiAlias,
    required this.isInvertColors,
    required this.strokeWidth,
    required this.style,
    required this.hasShader,
    required this.hasRuntimeShader,
    required this.hasColorFilter,
    required this.colorFilterMayAffectTransparentBlack,
    required this.maskBlurSigma,
    required this.imageFilter,
  });

  factory PaintAttrs.of(ui.Paint paint) {
    final cf = paint.colorFilter;
    final cfAffectsTransparentBlack =
        cf != null && colorFilterModifiesTransparentBlack(cf);
    final mf = paint.maskFilter;
    return PaintAttrs(
      alpha: paint.color.a,
      blendMode: paint.blendMode,
      isAntiAlias: paint.isAntiAlias,
      isInvertColors: paint.invertColors,
      strokeWidth: paint.strokeWidth,
      style: paint.style,
      hasShader: paint.shader != null,
      // `current_.usesRuntimeEffect()` (dl_builder.h:736): only Fragment
      // shaders (RuntimeEffect) are incompatible; gradient/ImageShaders are.
      hasRuntimeShader: paint.shader is ui.FragmentShader,
      hasColorFilter: cf != null,
      colorFilterMayAffectTransparentBlack: cfAffectsTransparentBlack,
      maskBlurSigma: _maskBlurSigma(mf),
      imageFilter: FilterDesc.describe(paint.imageFilter),
    );
  }

  final double alpha;
  final ui.BlendMode blendMode;
  final bool isAntiAlias;
  final bool isInvertColors;
  final double strokeWidth;
  final ui.PaintingStyle style;
  final bool hasShader;
  final bool hasRuntimeShader;
  final bool hasColorFilter;

  /// `Paint::color_filter->modifies_transparent_black()` equivalent.
  final bool colorFilterMayAffectTransparentBlack;

  /// `Paint::mask_blur_descriptor` sigma, or 0.
  final double maskBlurSigma;

  final FilterDesc? imageFilter;

  // dl_blend_color_filter.cc:47: these modes act like kSrc on a
  // transparent-black destination, so they modify it iff the src color is
  // not transparent.
  static const _mtbModes = {
    'src',
    'srcOver',
    'dstOver',
    'srcOut',
    'dstATop',
    'xor',
    'plus',
    'screen',
    'overlay',
    'darken',
    'lighten',
    'colorDodge',
    'colorBurn',
    'hardLight',
    'softLight',
    'difference',
    'exclusion',
    'multiply',
    'hue',
    'saturation',
    'color',
    'luminosity',
  };

  static bool colorFilterModifiesTransparentBlack(ui.ColorFilter f) {
    final s = f.toString();
    if (s.startsWith('ColorFilter.mode(')) {
      // toString: 'ColorFilter.mode(Color(alpha: A, red: R, ...), BlendMode.X)'
      // (painting.dart:4261-4264, Color.toString at painting.dart:529).
      final alpha = RegExp(r'alpha:\s*([\d.]+)').firstMatch(s);
      // Unparseable alpha → conservative: treat as non-transparent.
      final isTransparent = alpha != null && double.parse(alpha.group(1)!) == 0;
      final mode = RegExp(r'BlendMode\.(\w+)').firstMatch(s)?.group(1);
      return !isTransparent && _mtbModes.contains(mode);
    }
    if (s.startsWith('ColorFilter.matrix(')) {
      // dl_matrix_color_filter.cc:23: MTB iff matrix[19] > 0 — the alpha
      // output's constant term. toString prints `Float64List` contents:
      // 'ColorFilter.matrix([r00, r01, ..., r33])' — element 19 is the last.
      final nums = RegExp(
        r'-?\d+\.\d+(?:[eE][+-]?\d+)?',
      ).allMatches(s).map((m) => double.parse(m.group(0)!)).toList();
      if (nums.length >= 20) {
        return nums[19] > 0;
      }
      return true; // unparseable — conservative
    }
    // linearToSrgbGamma / srgbToLinearGamma do not affect transparent black.
    return false;
  }

  static double _maskBlurSigma(ui.MaskFilter? mf) {
    if (mf == null) {
      return 0;
    }
    final m = RegExp(
      r'MaskFilter\.blur\([^,]+, ([\d.eE+-]+)',
    ).firstMatch('$mf');
    return m != null ? double.parse(m.group(1)!) : 0;
  }

  /// `Paint::CanApplyOpacityPeephole` (paint.h:42).
  bool get canApplyOpacityPeephole =>
      blendMode == ui.BlendMode.srcOver &&
      !isInvertColors &&
      maskBlurSigma == 0 &&
      imageFilter == null &&
      !hasColorFilter;

  Map<String, Object?> toJson() => {
    'alpha': alpha,
    'blend': blendMode.name,
    if (imageFilter != null) 'imageFilter': imageFilter!.toJson(),
    if (hasColorFilter) 'colorFilter': true,
    if (maskBlurSigma > 0) 'maskBlurSigma': maskBlurSigma,
  };
}
