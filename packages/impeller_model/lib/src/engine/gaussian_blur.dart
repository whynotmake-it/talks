/// Which GPU passes an image filter costs, and how big they are.
///
/// Ports `impeller/entity/contents/filters/*_filter_contents.cc`.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import '../capture/recorded_op.dart';
import 'labels.dart';

/// ```engine impeller/entity/contents/filters/gaussian_blur_filter_contents.cc
/// constexpr Scalar kMaxSigma = 500.0f;
/// ```
const double kMaxSigma = 500.0;

/// ```engine impeller/geometry/sigma.cc
///   return Radius{sigma > 0.5f ? (sigma - 0.5f) * kKernelRadiusPerSigma : 0.0f};
/// ```
double calculateBlurRadius(double sigma) =>
    sigma > 0.5 ? (sigma - 0.5) * 1.73205080757 : 0.0;

/// ```engine impeller/entity/contents/filters/gaussian_blur_filter_contents.cc
/// Scalar GaussianBlurFilterContents::ScaleSigma(Scalar sigma) {
///   // Limit the kernel size to 1000x1000 pixels, like Skia does.
///   Scalar clamped = std::min(sigma, kMaxSigma);
///   constexpr Scalar a = 3.4e-06;
///   constexpr Scalar b = -3.4e-3;
///   constexpr Scalar c = 1.f;
///   Scalar scalar = c + b * clamped + a * clamped * clamped;
///   return clamped * scalar;
/// ```
double scaleSigma(double sigma) {
  final clamped = math.min(sigma, kMaxSigma);
  const a = 3.4e-06;
  const b = -3.4e-3;
  const c = 1.0;
  final scalar = c + b * clamped + a * clamped * clamped;
  return clamped * scalar;
}

/// Downsample factor chosen by scaled sigma (physical pixels).
///
/// ```engine impeller/entity/contents/filters/gaussian_blur_filter_contents.cc
/// Scalar GaussianBlurFilterContents::CalculateScale(Scalar sigma) {
///   if (sigma <= 4) {
///     return 1.0;
///   }
///   Scalar raw_result = 4.0 / sigma;
///   // Round to the nearest 1/(2^n) to get the best quality down scaling.
///   Scalar exponent = round(log2f(raw_result));
///   // Don't scale down below 1/16th to preserve signal.
///   exponent = std::max(-4.0f, exponent);
/// ```
double calculateBlurScale(double scaledSigma) {
  if (scaledSigma <= 4) {
    return 1.0;
  }
  final rawResult = 4.0 / scaledSigma;
  var exponent = (math.log(rawResult) / math.ln2).roundToDouble();
  // Don't scale below 1/16.
  exponent = math.max(-4.0, exponent);
  final rounded = math.pow(2.0, exponent).toDouble();
  var result = rounded;
  // ```engine impeller/entity/contents/filters/gaussian_blur_filter_contents.cc
  //   // Extend the range of the 1/8th downsample based on the effective kernel size
  //   // for the blur.
  //   if (rounded < 0.125f) {
  //     Scalar rounded_plus = powf(2.0f, exponent + 1);
  // ```
  if (rounded < 0.125) {
    final roundedPlus = math.pow(2.0, exponent + 1).toDouble();
    final blurRadius = calculateBlurRadius(scaledSigma);
    final kernelSizePlus = (scaleBlurRadius(blurRadius, roundedPlus) * 2) + 1;
    const kEighthDownsampleKernelWidthMax = 41;
    result = kernelSizePlus <= kEighthDownsampleKernelWidthMax
        ? roundedPlus
        : rounded;
  }
  return result;
}

/// ```engine impeller/entity/contents/filters/gaussian_blur_filter_contents.cc
/// int ScaleBlurRadius(Scalar radius, Scalar scalar) {
///   return static_cast<int>(std::round(radius * scalar));
/// ```
int scaleBlurRadius(double radius, double scalar) => (radius * scalar).round();

/// The kind of standalone render pass a filter spawns.
enum FilterPassKind {
  blurDownsample('downsample'),
  blurY('vertical blur'),
  blurX('horizontal blur'),
  morphology('morphology'),
  inputSnapshot('filter input snapshot'),
  unknownFilter('filter');

  const FilterPassKind(this.description);
  final String description;
}

/// One standalone render pass a filter costs.
class FilterPassEstimate {
  FilterPassEstimate({
    required this.kind,
    required this.size,
    required this.engineLabel,
    this.inputReadArea = 0,
    this.approximate = false,
  });
  final FilterPassKind kind;
  final ui.Size size;

  /// The render pass label a GPU capture shows for this pass.
  final String engineLabel;

  /// Pixel area this pass samples from its input texture at full
  /// resolution (the downsample pass reads the whole blur source).
  final double inputReadArea;

  /// True when the pass shape is a guess, not a port (unknown filters).
  final bool approximate;
}

/// Passes for [filter] applied to an input texture of [inputSize] whose
/// output is only needed inside [coverageHint] (both in pass pixels), with
/// the transform basis [basisScale] of the filtered content.
List<FilterPassEstimate> estimateFilterPasses(
  FilterDesc filter, {
  required ui.Rect input,
  required ui.Size basisScale,
  ui.Rect? coverageHint,
}) {
  switch (filter.kind) {
    case 'blur':
      return _gaussianBlurPasses(filter, input, coverageHint, basisScale);
    case 'matrix':
      // MatrixFilterContents only re-transforms the input snapshot: no pass.
      //
      // ```engine impeller/entity/contents/filters/filter_contents.cc
      // std::shared_ptr<FilterContents> FilterContents::MakeMatrixFilter(
      // ```
      return const [];
    case 'colorFilter':
      // A color filter on its own is applied while the filtered texture is
      // drawn: no pass. (Inside a compose, see below.)
      return const [];
    case 'compose':
      // ImageFilter.compose(outer, inner): inner runs first, outer consumes
      // its output. A color filter produces no texture, so a blur consuming
      // it first snapshots it, over the coverage hint grown by the blur's
      // padding; the blur then downsamples that snapshot as a whole
      // (confirmed in count and size by the cupertino_alert scene on Pixel
      // 10 and in labels on macOS):
      //
      // ```engine impeller/entity/contents/filters/gaussian_blur_filter_contents.cc
      //     expanded_coverage_hint = coverage_hint->Expand(blur_info.local_padding);
      // ```
      final inner = filter.inner;
      final outer = filter.outer;
      if (inner?.kind == 'colorFilter' && outer?.kind == 'blur') {
        final region = coverageHint ?? input;
        final pad = _blurPadding(outer!, basisScale);
        final snapshot = ui.Rect.fromLTRB(
          region.left - pad.width,
          region.top - pad.height,
          region.right + pad.width,
          region.bottom + pad.height,
        );
        return [
          FilterPassEstimate(
            kind: FilterPassKind.inputSnapshot,
            size: ui.Size(
              snapshot.width.ceilToDouble(),
              snapshot.height.ceilToDouble(),
            ),
            engineLabel: EngineLabels.gaussianBlurInputSnapshot,
          ),
          ..._gaussianBlurPasses(outer, snapshot, null, basisScale),
        ];
      }
      return [
        if (inner != null)
          ...estimateFilterPasses(
            inner,
            input: input,
            coverageHint: coverageHint,
            basisScale: basisScale,
          ),
        if (outer != null)
          ...estimateFilterPasses(
            outer,
            input: input,
            coverageHint: coverageHint,
            basisScale: basisScale,
          ),
      ];
    case 'dilate':
    case 'erode':
      // Two directional passes, x then y.
      //
      // ```engine impeller/entity/contents/filters/filter_contents.cc
      //   auto x_morphology = MakeDirectionalMorphology(std::move(input), radius_x,
      //                                                 Point(1, 0), morph_type);
      //   auto y_morphology = MakeDirectionalMorphology(
      //       FilterInput::Make(x_morphology), radius_y, Point(0, 1), morph_type);
      // ```
      final size = (coverageHint ?? input).size;
      return [
        for (var i = 0; i < 2; i++)
          FilterPassEstimate(
            kind: FilterPassKind.morphology,
            size: size,
            engineLabel: EngineLabels.morphologyFilter,
          ),
      ];
    default:
      return [
        FilterPassEstimate(
          kind: FilterPassKind.unknownFilter,
          size: (coverageHint ?? input).size,
          engineLabel: EngineLabels.snapshot,
          approximate: true,
        ),
      ];
  }
}

/// Gaussian blur = downsample + Y + X, three render passes in three command
/// buffers, all at the downsampled size.
///
/// ```engine impeller/entity/contents/filters/gaussian_blur_filter_contents.cc
///   fml::StatusOr<RenderTarget> pass1_out = MakeDownsampleSubpass(
/// ```
/// ```engine impeller/entity/contents/filters/gaussian_blur_filter_contents.cc
///   fml::StatusOr<RenderTarget> pass2_out = MakeBlurSubpass(
/// ```
/// ```engine impeller/entity/contents/filters/gaussian_blur_filter_contents.cc
///   fml::StatusOr<RenderTarget> pass3_out = MakeBlurSubpass(
/// ```
List<FilterPassEstimate> _gaussianBlurPasses(
  FilterDesc filter,
  ui.Rect input,
  ui.Rect? coverageHint,
  ui.Size basisScale,
) {
  // ```engine impeller/entity/contents/filters/gaussian_blur_filter_contents.cc
  //   Vector2 scaled_sigma =
  //       (effect_transform.Basis() * Matrix::MakeScale(source_space_scalar) *  //
  //        Vector2(GaussianBlurFilterContents::ScaleSigma(sigma.x),
  //                GaussianBlurFilterContents::ScaleSigma(sigma.y)))
  //           .Abs();
  //   scaled_sigma = Clamp(scaled_sigma, 0, kMaxSigma);
  // ```
  final sx = math.min(scaleSigma(filter.sigmaX) * basisScale.width, kMaxSigma);
  final sy = math.min(
    scaleSigma(filter.sigmaY) * basisScale.height,
    kMaxSigma,
  );
  // ```engine impeller/entity/contents/filters/gaussian_blur_filter_contents.cc
  //   if (blur_info.scaled_sigma.x < kEhCloseEnough &&
  //       blur_info.scaled_sigma.y < kEhCloseEnough) {
  // ```
  const kEhCloseEnough = 1e-3;
  if (sx < kEhCloseEnough && sy < kEhCloseEnough) {
    return const [];
  }
  final pad = _blurPadding(filter, basisScale);
  final padX = pad.width;
  final padY = pad.height;
  // ```engine impeller/entity/contents/filters/gaussian_blur_filter_contents.cc
  //   Scalar desired_scalar =
  //       std::min(GaussianBlurFilterContents::CalculateScale(scaled_sigma.x),
  //                GaussianBlurFilterContents::CalculateScale(scaled_sigma.y));
  // ```
  final scalar = math.min(calculateBlurScale(sx), calculateBlurScale(sy));
  final divisor = (1.0 / scalar).roundToDouble();

  // CalculateDownsamplePassArgs has two branches. When the padded coverage
  // hint fits inside the input (a clipped backdrop), only the hint is
  // downsampled, aligned to the divisor:
  //
  // ```engine impeller/entity/contents/filters/gaussian_blur_filter_contents.cc
  //   if (input_snapshot.transform.Equals(snapshot_entity.GetTransform()) &&
  //       source_expanded_coverage_hint.has_value() &&
  //       snapshot_coverage.has_value() &&
  //       snapshot_coverage->Contains(source_expanded_coverage_hint.value())) {
  // ```
  //
  // Otherwise the whole input texture plus padding is downsampled:
  //
  // ```engine impeller/entity/contents/filters/gaussian_blur_filter_contents.cc
  //     Rect source_rect_padded = source_rect.Expand(padding);
  //     Vector2 downsampled_size = source_rect_padded.GetSize() * downsample_scalar;
  //     ISize subpass_size =
  //         ISize(ceil(downsampled_size.x), ceil(downsampled_size.y));
  // ```
  final hint = coverageHint == null
      ? null
      : ui.Rect.fromLTRB(
          coverageHint.left - padX,
          coverageHint.top - padY,
          coverageHint.right + padX,
          coverageHint.bottom + padY,
        );
  final double w, h, readW, readH;
  if (hint != null && _contains(input, hint)) {
    w = (hint.width / divisor).ceil() * divisor * scalar;
    h = (hint.height / divisor).ceil() * divisor * scalar;
    readW = hint.width;
    readH = hint.height;
  } else {
    w = ((input.width + 2 * padX) * scalar).ceilToDouble();
    h = ((input.height + 2 * padY) * scalar).ceilToDouble();
    readW = input.width;
    readH = input.height;
  }
  final size = ui.Size(w, h);
  return [
    FilterPassEstimate(
      kind: FilterPassKind.blurDownsample,
      size: size,
      engineLabel: EngineLabels.gaussianBlurFilter,
      inputReadArea: readW * readH,
    ),
    FilterPassEstimate(
      kind: FilterPassKind.blurY,
      size: size,
      engineLabel: EngineLabels.gaussianBlurFilter,
    ),
    FilterPassEstimate(
      kind: FilterPassKind.blurX,
      size: size,
      engineLabel: EngineLabels.gaussianBlurFilter,
    ),
  ];
}

/// The transparent gutter a blur adds around its input, in pixels.
///
/// ```engine impeller/entity/contents/filters/gaussian_blur_filter_contents.cc
///   Vector2 padding(ceil(blur_radius.x), ceil(blur_radius.y));
/// ```
ui.Size _blurPadding(FilterDesc blur, ui.Size basisScale) {
  final sx = math.min(scaleSigma(blur.sigmaX) * basisScale.width, kMaxSigma);
  final sy = math.min(scaleSigma(blur.sigmaY) * basisScale.height, kMaxSigma);
  return ui.Size(
    calculateBlurRadius(sx).ceilToDouble(),
    calculateBlurRadius(sy).ceilToDouble(),
  );
}

bool _contains(ui.Rect outer, ui.Rect inner) =>
    inner.left >= outer.left &&
    inner.top >= outer.top &&
    inner.right <= outer.right &&
    inner.bottom <= outer.bottom;
